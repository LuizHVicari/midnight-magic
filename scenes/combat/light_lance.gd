class_name LightLance
extends Node3D
## One lance of light: a single long, thin streak that comes to a sharp point, with a cloud of
## tiny motes shed along its whole length. It trembles all the time. It hovers where the [LightAttack] puts it, then, once launched, stretches, flies fast and bends
## a little towards the target it was aimed near.

const SHADER := preload("res://assets/shaders/light_lance.gdshader")
const LENGTH := 2.4
const STREAK := 1.5  # how much longer the spear looks at full speed
const SPEED := 60.0
const DAMAGE := 8.0
const HOMING := 5.0  # how fast the heading bends towards the target, per second
const HOMING_REACH := 80.0
const HOMING_CONE := 22.0
const MAX_RANGE := 100.0  # far beyond fire's reach
const LIFETIME := MAX_RANGE / SPEED
const CONJURE_TIME := 0.2
## The lance lights up its surroundings: gold-white, steady and wide. A volley adds up, so a big
## one lights a whole clearing.
const GLOW_COLOR := Color(1.0, 0.9, 0.6)
const GLOW_RANGE := 9.0
const GLOW_HOVER := 0.07
const GLOW_FLYING := 0.3
const SHAKE_EVERY := 0.03  # the body jumps to a new tremble this often, for a jittery look

var element: Element
var caster: Player
## Where the lance hovers, relative to the hero: x right, y up, z behind (camera yaw frame).
var slot := Vector3.ZERO

var _flying := false
var _direction := Vector3.FORWARD
var _target: Health
var _age := 0.0
var _bob := randf() * TAU
var _shake_wait := 0.0
var _body := Node3D.new()  # the beams; stretched while flying, shaken all the time
var _glow := OmniLight3D.new()
var _materials: Array[ShaderMaterial] = []


func _ready() -> void:
	var rgb := Vector3(element.color.r, element.color.g, element.color.b)
	# Tip at the origin, the streak trailing along +Z.
	_body.add_child(_beam(0.045, 0.0, LENGTH, 0.0, rgb, 1.3, 1.5, 0.8, 0.7, 0.5, 0.02))
	add_child(_body)

	var motes := Vfx.motes(element.color, 34, 0.55, LENGTH * 0.9, 0.12)
	motes.position.z = LENGTH * 0.5
	add_child(motes)
	motes.emitting = true
	Vfx.sparks(get_parent(), global_position, element.color, 6)

	_glow.light_color = GLOW_COLOR
	_glow.omni_range = GLOW_RANGE
	_glow.omni_attenuation = 0.9
	_glow.light_energy = 0.0
	_glow.position.z = LENGTH * 0.4
	add_child(_glow)
	scale = Vector3.ZERO


func _process(delta: float) -> void:
	_age += delta
	var conjure := smoothstep(0.0, CONJURE_TIME, _age)
	scale = Vector3.ONE * conjure
	# Scaling the node would shrink the light's range with it, so size and brightness follow the
	# conjuring separately, and a lance in flight burns brighter.
	_glow.omni_range = GLOW_RANGE / maxf(conjure, 0.05)
	_glow.light_energy = (GLOW_FLYING if _flying else GLOW_HOVER) * conjure * randf_range(0.9, 1.0)
	_shake_wait -= delta
	if _shake_wait <= 0.0:
		_shake_wait = SHAKE_EVERY
		_shake()


## Jumps the body a hair off-axis and flickers it. It shivers harder while waiting to be loosed.
func _shake() -> void:
	var amount := 0.4 if _flying else 1.0
	_body.position = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-0.3, 0.3)) * 0.04 * amount
	_body.rotation = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * deg_to_rad(2.2) * amount
	var flicker := randf_range(0.7, 1.0)
	for material in _materials:
		material.set_shader_parameter("fade", flicker)


## Follows the hero while waiting, tip towards the aim point.
func hover(anchor: Vector3, yaw: float, aim: Vector3) -> void:
	var sway := Vector3(0.0, sin(Time.get_ticks_msec() / 1000.0 * 3.0 + _bob) * 0.06, 0.0)
	global_position = anchor + Basis(Vector3.UP, yaw) * slot + sway
	if global_position.distance_squared_to(aim) > 1.0:
		look_at(aim)


func launch(aim: Vector3) -> void:
	_direction = (aim - global_position).normalized()
	_target = Combat.find_target(self, global_position, _direction, HOMING_REACH, HOMING_CONE)
	_age = CONJURE_TIME
	_flying = true
	_body.scale.z = STREAK
	var life := get_tree().create_timer(LIFETIME)
	life.timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	if not _flying:
		return
	if _target != null and _target.is_alive():
		var wanted := (_target.focus_point() - global_position).normalized()
		_direction = _direction.slerp(wanted, clampf(HOMING * delta, 0.0, 1.0)).normalized()
	var from := global_position
	var to := from + _direction * SPEED * delta
	var hit := Combat.raycast(self, from, to, [caster.get_rid()])
	if hit.is_empty():
		global_position = to
		look_at(to + _direction)
		return
	Combat.hurt(hit["collider"], DAMAGE, element)
	Vfx.sparks(get_parent(), hit["position"], element.color)
	Vfx.flash(get_parent(), hit["position"] + Vector3.UP * 0.3, GLOW_COLOR, 3.0, 9.0, 0.2)
	queue_free()


## One layer of the spear: a cone or tapering shaft of [param length] starting [param start]
## behind the tip, [param base_radius] wide at the tail end and [param tip_radius] at the front.
func _beam(
	base_radius: float, tip_radius: float, length: float, start: float, rgb: Vector3,
	brightness: float, opacity: float, edge: float, tail: float, hot: float, tremble: float,
) -> MeshInstance3D:
	var cone := CylinderMesh.new()
	cone.top_radius = tip_radius
	cone.bottom_radius = base_radius
	cone.height = length
	cone.radial_segments = 10
	cone.cap_top = false
	cone.cap_bottom = false
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("color", rgb)
	material.set_shader_parameter("brightness", brightness)
	material.set_shader_parameter("opacity", opacity)
	material.set_shader_parameter("edge_power", edge)
	material.set_shader_parameter("tail_power", tail)
	material.set_shader_parameter("hot", hot)
	material.set_shader_parameter("tremble", tremble)
	material.set_shader_parameter("phase", randf() * TAU)
	_materials.append(material)
	var beam := MeshInstance3D.new()
	beam.mesh = cone
	beam.material_override = material
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The cylinder's top (+Y) is the front: turn it to -Z, with its front end [start] behind the tip.
	beam.rotation.x = -PI / 2.0
	beam.position.z = start + length * 0.5
	return beam
