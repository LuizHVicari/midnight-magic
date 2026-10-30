class_name LightReticle
extends Node3D
## A ring of light on the ground marking where an area spell will land. Scale it with
## [method set_radius]; [method fade_out] lets it go when the spell is loosed.

const SHADER := preload("res://assets/shaders/area_ring.gdshader")

var _mesh := MeshInstance3D.new()
var _material := ShaderMaterial.new()
var _sparkles: GPUParticles3D


func _init() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_material.shader = SHADER
	quad.material = _material
	_mesh.mesh = quad
	_mesh.rotation_degrees.x = -90.0  # lie flat, facing up
	_mesh.position.y = 0.12  # just above the ground so it does not flicker into it
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	_sparkles = Vfx.sparkles(1.0, 0.1, 44, 1.4, 0.2, Color(1.0, 0.85, 0.4), 1.3)
	add_child(_sparkles)


func set_radius(radius: float) -> void:
	_mesh.scale = Vector3(radius * 2.0, radius * 2.0, 1.0)
	(_sparkles.process_material as ParticleProcessMaterial).emission_ring_radius = radius * 0.95
	_sparkles.amount = clampi(int(radius * 14.0), 20, 90)


func set_color(color: Color) -> void:
	_material.set_shader_parameter("color", Vector3(color.r, color.g, color.b))
	var process := _sparkles.process_material as ParticleProcessMaterial
	process.color_ramp = Vfx.ramp([Color(1, 1, 1, 1) * 1.6, Color(color * 1.8, 1.0), Color(color, 1.0), Color(0, 0, 0, 1)])


## A quick swell of the ring, like a beat.
func pulse() -> void:
	var rest := _mesh.scale
	var tween := create_tween()
	tween.tween_property(_mesh, "scale", rest * 1.1, 0.07)
	tween.tween_property(_mesh, "scale", rest, 0.25)


func fade_out(time: float) -> void:
	var tween := create_tween()
	tween.tween_method(_set_fade, 1.0, 0.0, time)
	tween.tween_callback(queue_free)


func _set_fade(value: float) -> void:
	_material.set_shader_parameter("fade", value)
