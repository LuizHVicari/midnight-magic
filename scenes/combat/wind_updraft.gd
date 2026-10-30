class_name WindUpdraft
extends Node3D
## A column of rising air standing on the ground. Everything inside it that walks is carried
## upwards, the hero faster and in control of where they go (they can glide off the top), the
## others helpless until the column lets them go and they fall. It rises from where it is put,
## lasts a while and then thins out.

const SHADER := preload("res://assets/shaders/wind_column.gdshader")
const RADIUS := 2.4
const HEIGHT := 15.0
const LIFETIME := 9.0
const HERO_SPEED := 11.0
const OTHER_SPEED := 8.0
const FADE_TIME := 1.0
const MINT := Color(0.55, 1.0, 0.82)

var element: Element
var caster: Player

var _age := 0.0
var _material := ShaderMaterial.new()
var _ring: LightReticle


func _ready() -> void:
	var tube := CylinderMesh.new()
	tube.top_radius = RADIUS
	tube.bottom_radius = RADIUS
	tube.height = HEIGHT
	tube.radial_segments = 20
	tube.rings = 1
	tube.cap_top = false
	tube.cap_bottom = false
	_material.shader = SHADER
	_material.set_shader_parameter("color", Vector3(MINT.r, MINT.g, MINT.b))
	_material.set_shader_parameter("height", HEIGHT)
	_material.set_shader_parameter("flow", 1.6)
	_material.set_shader_parameter("twist", 1.5)
	_material.set_shader_parameter("bands", 7.0)
	tube.material = _material
	var column := MeshInstance3D.new()
	column.mesh = tube
	column.position.y = HEIGHT * 0.5
	column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(column)

	_ring = LightReticle.new()
	_ring.set_color(MINT)
	_ring.set_radius(RADIUS)
	add_child(_ring)
	add_child(_flecks())
	Vfx.sparks(get_parent(), global_position + Vector3.UP * 0.3, MINT, 14)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	_material.set_shader_parameter("fade", clampf((LIFETIME - _age) / FADE_TIME, 0.0, 1.0))
	if _inside(caster.global_position + Vector3.UP):
		caster.lift(delta, HERO_SPEED)
	for health: Health in get_tree().get_nodes_in_group("damageable"):
		var animal := health.get_parent() as Animal
		if animal != null and _inside(animal.global_position):
			animal.lift(OTHER_SPEED)


func _inside(point: Vector3) -> bool:
	var flat := Vector2(point.x - global_position.x, point.z - global_position.z)
	return flat.length() <= RADIUS and point.y >= global_position.y - 0.8 and point.y <= global_position.y + HEIGHT


## Pale flecks rising through the column.
func _flecks() -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	process.emission_ring_axis = Vector3.UP
	process.emission_ring_radius = RADIUS * 0.9
	process.emission_ring_inner_radius = 0.0
	process.emission_ring_height = 0.2
	process.direction = Vector3.UP
	process.spread = 6.0
	process.initial_velocity_min = 7.0
	process.initial_velocity_max = 11.0
	process.gravity = Vector3.ZERO
	process.scale_min = 0.5
	process.scale_max = 1.1
	process.color_ramp = Vfx.ramp([Color(0.9, 1.0, 0.95, 0.0), Color(0.8, 1.0, 0.92, 0.9), Color(0.55, 1.0, 0.82, 0.0)])
	var emitter := Vfx.particles(process, Vfx.soft_quad(0.3), 60, 1.6)
	emitter.local_coords = true
	emitter.emitting = true
	return emitter
