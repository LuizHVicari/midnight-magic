class_name Nameplate
extends Node3D
## Floating tag over a creature: its name above a health bar, both always facing the camera. It is
## hidden until [method show_plate] turns it on, which the owner does while the creature is
## fighting, so you can tell what is attacking you and how hurt it is.

const BAR_SHADER := preload("res://assets/shaders/nameplate_bar.gdshader")
const BAR_SIZE := Vector2(1.5, 0.17)

var _label := Label3D.new()
var _bar := MeshInstance3D.new()
var _material := ShaderMaterial.new()


func _init() -> void:
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 44
	_label.pixel_size = 0.006
	_label.outline_size = 12
	_label.outline_modulate = Color(0.1, 0.06, 0.15)
	_label.position.y = BAR_SIZE.y + 0.12
	add_child(_label)

	var quad := QuadMesh.new()
	quad.size = BAR_SIZE
	_material.shader = BAR_SHADER
	_material.set_shader_parameter("aspect", BAR_SIZE.x / BAR_SIZE.y)
	quad.material = _material
	_bar.mesh = quad
	_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_bar)
	visible = false


func setup(text: String, color: Color) -> void:
	_label.text = text
	_label.modulate = color


func set_ratio(ratio: float) -> void:
	_material.set_shader_parameter("ratio", clampf(ratio, 0.0, 1.0))


func show_plate(on: bool) -> void:
	visible = on
