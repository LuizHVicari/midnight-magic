class_name BlackoutZone
extends Node3D
## A zone of living darkness standing on the ground for a good while. Foes inside it, and foes
## looking at a hero inside it, see only a fifth as far, so a hero can walk through a camp unseen.
## Hearing is not touched: it is still no help to run. A hero who gives off light of their own
## (an orb, a flash) is only half hidden. It looks like a dome of black smoke from outside, and the
## hero's own screen darkens at the edges while inside (see [ShadowVeil]).

const DOME := preload("res://assets/shaders/dark_dome.gdshader")
const GROUND := preload("res://assets/shaders/dark_ground.gdshader")
const SIGHT_DARK := 0.2
const SIGHT_LIT := 0.6
const GROW := 0.8
const FADE := 1.6
const VIOLET := Color(0.6, 0.25, 0.92)

## Set before it enters the tree.
var radius := 9.0
var duration := 25.0

var _age := 0.0
var _materials: Array[ShaderMaterial] = []
var _sparkles: Array[GPUParticles3D] = []
var _light := OmniLight3D.new()
var _visual := Node3D.new()
var _orbit: Node3D


func _ready() -> void:
	add_to_group("blackout_zones")
	_visual.scale = Vector3(0.2, 0.2, 0.2)
	add_child(_visual)
	_visual.add_child(_dome())
	_visual.add_child(_ground())
	_visual.add_child(_smoke())
	var sparkles := Vfx.sparkles(radius * 0.9, 0.6, 90, 2.4, 0.26, VIOLET, 1.1, radius * 0.1)
	_visual.add_child(sparkles)
	_sparkles.append(sparkles)
	var beads: Array[Color] = [VIOLET * 1.6, Color(0.9, 0.5, 1.0) * 1.4]
	var orbit := Vfx.orbiters(26, Vector2(radius * 0.45, radius * 0.95), Vector2(0.4, radius * 0.6), beads, Vector2(0.05, 0.1), false, 51)
	_orbit = orbit
	_visual.add_child(orbit)
	# A light that takes light away: the zone is darker than the world around it.
	_light.light_negative = true
	_light.light_energy = 1.7
	_light.omni_range = radius * 1.7
	_light.omni_attenuation = 0.8
	_light.position.y = 1.5
	_visual.add_child(_light)
	create_tween().tween_property(_visual, "scale", Vector3.ONE, GROW).set_ease(Tween.EASE_OUT)
	Vfx.sparks(get_parent(), global_position + Vector3.UP * 0.3, VIOLET, 20)


func _physics_process(delta: float) -> void:
	_age += delta
	_orbit.rotate_y(0.45 * delta)
	var left := duration - _age
	if left <= 0.0:
		queue_free()
		return
	var fade := clampf(left / FADE, 0.0, 1.0)
	for material in _materials:
		material.set_shader_parameter("fade", fade)
	for emitter in _sparkles:
		emitter.emitting = left > 0.6
	_light.light_energy = 1.7 * fade


## Whether [param point] is inside the zone.
func covers(point: Vector3) -> bool:
	var flat := Vector2(point.x - global_position.x, point.z - global_position.z)
	return flat.length() <= radius and point.y >= global_position.y - 2.0 and point.y <= global_position.y + radius


## Whether any blackout covers [param point].
static func contains(tree: SceneTree, point: Vector3) -> bool:
	for zone: BlackoutZone in tree.get_nodes_in_group("blackout_zones"):
		if zone.covers(point):
			return true
	return false


## How much of its normal sight range a foe at [param foe_at] keeps when looking for [param hero]:
## less than half if either stands in a blackout, and not so little if the hero is lit.
static func sight_factor(tree: SceneTree, foe_at: Vector3, hero: Player) -> float:
	if not (contains(tree, foe_at) or contains(tree, hero.global_position)):
		return 1.0
	return SIGHT_LIT if hero.is_lit() else SIGHT_DARK


func _dome() -> MeshInstance3D:
	var half := SphereMesh.new()
	half.radius = radius
	half.height = radius
	half.is_hemisphere = true
	half.radial_segments = 28
	half.rings = 12
	half.material = _shader(DOME)
	var dome := MeshInstance3D.new()
	dome.mesh = half
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return dome


func _ground() -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * radius * 2.0
	quad.material = _shader(GROUND)
	var disc := MeshInstance3D.new()
	disc.mesh = quad
	disc.rotation_degrees.x = -90.0
	disc.position.y = 0.12
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return disc


func _shader(shader: Shader) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	_materials.append(material)
	return material


## Dense dark smoke rising off the whole disc and curling at the top.
func _smoke() -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	process.emission_ring_axis = Vector3.UP
	process.emission_ring_radius = radius * 0.95
	process.emission_ring_inner_radius = 0.0
	process.emission_ring_height = 0.3
	process.direction = Vector3.UP
	process.spread = 12.0
	process.initial_velocity_min = 0.4
	process.initial_velocity_max = 1.3
	process.gravity = Vector3.ZERO
	process.scale_min = 1.2
	process.scale_max = 2.4
	process.scale_curve = Vfx.puff_curve()
	process.color_ramp = Vfx.ramp([Color(0.02, 0.0, 0.05, 0.0), Color(0.05, 0.01, 0.1, 0.55), Color(0.1, 0.03, 0.2, 0.0)])
	var emitter := Vfx.particles(process, Vfx.alpha_quad(2.6), 90, 4.0)
	emitter.local_coords = true
	emitter.emitting = true
	return emitter

