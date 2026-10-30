class_name ShadowDread
extends Node3D
## The look of the dread spell, a one-off at the hero's feet: a shell of black smoke that swells
## out across the whole area, a ring of tendrils of living shadow that rise round the hero and
## sink again, a burst of thick dark smoke thrown outwards, violet sparks, and a light that takes
## light away for a moment.

const DOME := preload("res://assets/shaders/dark_dome.gdshader")
const VIOLET := Color(0.6, 0.25, 0.92)
const TENDRILS := 36
const SWELL := 0.75
const TIME := 2.4

## How far the dread reaches; set before it enters the tree.
var radius := 12.0


func _ready() -> void:
	_shell()
	_tendrils()
	add_child(_smoke())
	add_child(_stars())
	_darken()
	Vfx.sparks(get_parent(), global_position + Vector3.UP * 0.5, VIOLET, 24)
	get_tree().create_timer(TIME + 0.6).timeout.connect(queue_free)


## The black shell sweeping out and thinning away.
func _shell() -> void:
	var material := ShaderMaterial.new()
	material.shader = DOME
	material.set_shader_parameter("inside_alpha", 0.35)
	material.set_shader_parameter("rim_alpha", 0.9)
	var half := SphereMesh.new()
	half.radius = 0.5
	half.height = 0.5
	half.is_hemisphere = true
	half.radial_segments = 24
	half.rings = 10
	half.material = material
	var dome := MeshInstance3D.new()
	dome.mesh = half
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dome.scale = Vector3.ONE * 0.6
	add_child(dome)
	var tween := dome.create_tween().set_parallel()
	tween.tween_property(dome, "scale", Vector3.ONE * radius * 2.0, SWELL).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(value: float) -> void: material.set_shader_parameter("fade", value), 1.0, 0.0, TIME)
	tween.chain().tween_callback(dome.queue_free)


## Tendrils rising in a ring round the hero, growing, then sinking back into the ground.
func _tendrils() -> void:
	var ring := ShadowVfx.rising_tendrils(TENDRILS, 3.0)
	ring.scale = Vector3(0.05, 0.05, 0.05)
	add_child(ring)
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector3.ONE * 1.3, 0.55).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.9)
	tween.tween_property(ring, "scale", Vector3(1.3, 0.02, 1.3), 0.8).set_ease(Tween.EASE_IN)
	tween.tween_callback(ring.queue_free)


## Thick smoke flung out flat across the ground.
func _smoke() -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.6
	process.direction = Vector3.UP
	process.spread = 180.0
	process.flatness = 0.85
	process.initial_velocity_min = radius * 0.45
	process.initial_velocity_max = radius * 0.9
	process.damping_min = 3.0
	process.damping_max = 5.0
	process.gravity = Vector3(0.0, 0.8, 0.0)
	process.scale_min = 1.4
	process.scale_max = 2.8
	process.scale_curve = Vfx.puff_curve()
	process.color_ramp = Vfx.ramp([Color(0.04, 0.0, 0.09, 0.8), Color(0.07, 0.01, 0.13, 0.55), Color(0.03, 0.0, 0.06, 0.0)])
	var emitter := Vfx.particles(process, Vfx.alpha_quad(2.2), 70, 2.0)
	emitter.local_coords = false
	emitter.one_shot = true
	emitter.explosiveness = 0.9
	emitter.position.y = 0.4
	emitter.emitting = true
	return emitter


func _stars() -> GPUParticles3D:
	var emitter := Vfx.sparkles(radius * 0.7, 0.5, 120, 1.8, 0.3, VIOLET, 3.0, 1.0)
	emitter.one_shot = true
	emitter.explosiveness = 0.35
	return emitter


## A light that takes light away, strongest at the start.
func _darken() -> void:
	var light := OmniLight3D.new()
	light.light_negative = true
	light.light_energy = 3.0
	light.omni_range = radius * 1.6
	light.position.y = 1.5
	add_child(light)
	light.create_tween().tween_property(light, "light_energy", 0.0, TIME)
