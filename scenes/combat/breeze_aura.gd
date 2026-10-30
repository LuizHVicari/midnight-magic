class_name BreezeAura
extends Node3D
## The look of the breeze cloak: a thin whirl of wind round the hero, leaves and petals circling
## in it, a spray of twinkling stars rising off them and a faint ring turning on the ground.
## Follows the hero (it is their child); [method set_active] turns it on and off smoothly.

const SHADER := preload("res://assets/shaders/wind_column.gdshader")
const MINT := Color(0.55, 1.0, 0.82)
const HEIGHT := 2.5
const RADIUS := 1.05
const ORBIT := 2.6

var _swirl := MeshInstance3D.new()
var _material := ShaderMaterial.new()
var _leaves: Node3D
var _petals: Node3D
var _ring := LightReticle.new()
var _sparkles: Array[GPUParticles3D] = []
var _show := 0.0  # 0 hidden .. 1 fully shown
var _wanted := false


func _ready() -> void:
	var tube := CylinderMesh.new()
	tube.top_radius = RADIUS * 0.8
	tube.bottom_radius = RADIUS
	tube.height = HEIGHT
	tube.radial_segments = 18
	tube.rings = 1
	tube.cap_top = false
	tube.cap_bottom = false
	_material.shader = SHADER
	_material.set_shader_parameter("color", Vector3(MINT.r, MINT.g, MINT.b))
	_material.set_shader_parameter("height", HEIGHT)
	_material.set_shader_parameter("flow", 1.4)
	_material.set_shader_parameter("twist", 2.6)
	_material.set_shader_parameter("bands", 5.0)
	_material.set_shader_parameter("strength", 1.1)
	_material.set_shader_parameter("sway", 0.08)
	tube.material = _material
	_swirl.mesh = tube
	_swirl.position.y = HEIGHT * 0.5
	_swirl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_swirl)

	var leaf_colors: Array[Color] = [Color(0.55, 0.85, 0.5), Color(0.8, 0.95, 0.75), Color(0.4, 0.7, 0.45)]
	_leaves = Vfx.orbiters(16, Vector2(RADIUS * 0.8, RADIUS * 1.5), Vector2(0.1, 2.3), leaf_colors, Vector2(0.09, 0.16), true, 31)
	add_child(_leaves)
	var petal_colors: Array[Color] = [Color(1.0, 1.0, 1.0), Color(0.75, 1.0, 0.92)]
	_petals = Vfx.orbiters(12, Vector2(RADIUS * 0.5, RADIUS * 1.2), Vector2(0.3, 2.0), petal_colors, Vector2(0.05, 0.09), false, 37)
	add_child(_petals)

	_ring.set_color(MINT)
	_ring.set_radius(RADIUS * 1.5)
	add_child(_ring)
	_sparkles.append(Vfx.sparkles(RADIUS * 1.1, 0.2, 80, 1.6, 0.22, MINT, 1.4, RADIUS * 0.4))
	_sparkles.append(Vfx.sparkles(RADIUS * 0.6, 0.2, 36, 1.2, 0.18, Color(0.9, 1.0, 0.95), 2.0))
	for emitter in _sparkles:
		add_child(emitter)
	set_active(false)
	_apply(0.0)


func set_active(on: bool) -> void:
	_wanted = on
	for emitter in _sparkles:
		emitter.emitting = on


func _process(delta: float) -> void:
	_show = move_toward(_show, 1.0 if _wanted else 0.0, delta * 3.0)
	_apply(_show)
	if _show <= 0.0:
		return
	_leaves.rotate_y(ORBIT * delta)
	_petals.rotate_y(-ORBIT * 1.4 * delta)


func _apply(share: float) -> void:
	visible = share > 0.0
	_material.set_shader_parameter("fade", share)
	_leaves.scale = Vector3.ONE * share
	_petals.scale = Vector3.ONE * share
	_ring.scale = Vector3.ONE * share
