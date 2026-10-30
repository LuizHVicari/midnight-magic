class_name AlertMark
extends Node3D
## Gauge over a foe's head showing how close it is to noticing the hero: a ring that fills as
## awareness rises, with a "?" inside that turns into a red "!" once it fights. The ring is warm
## when it saw the hero and cool when it only heard them. Walls and trees hide it, so it
## only shows with a clear view of the foe, and it grows with distance to stay readable.

const SHADER := preload("res://assets/shaders/alert_ring.gdshader")
const SIZE := 0.8
const SEEN := Color(1.0, 0.85, 0.3)
const ANGRY := Color(1.0, 0.25, 0.2)
const HEARD := Color(0.5, 0.85, 1.0)
## Seen from farther than this it is scaled up so it keeps its apparent size.
const NEAR := 8.0
const FAR_SCALE := 3.0

var _glyph := Label3D.new()
var _ring := MeshInstance3D.new()
var _material := ShaderMaterial.new()


func _init() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * SIZE
	_material.shader = SHADER
	_material.render_priority = 10
	quad.material = _material
	_ring.mesh = quad
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)

	_glyph.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_glyph.render_priority = 11
	_glyph.font_size = 64
	_glyph.pixel_size = 0.0075
	_glyph.outline_size = 0
	_glyph.shaded = false
	add_child(_glyph)
	visible = false


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var away := camera.global_position.distance_to(global_position)
	scale = Vector3.ONE * clampf(away / NEAR, 1.0, FAR_SCALE)


## [param awareness] 0..1 fills the ring; [param fighting] shows the red "!"; [param heard] tints
## the ring cool when the foe only heard the hero.
## The look of a terrified foe: a full dark-violet ring pulsing round a dark crimson "!".
func show_fear() -> void:
	visible = true
	_glyph.text = "!"
	_glyph.modulate = Color(0.78, 0.1, 0.38)
	_material.set_shader_parameter("fill", 1.0)
	_material.set_shader_parameter("color", Vector3(0.45, 0.1, 0.72))
	_material.set_shader_parameter("pulse", 1.0)


func show_level(awareness: float, fighting: bool, heard: bool) -> void:
	visible = fighting or awareness >= 0.12
	if not visible:
		return
	var color := HEARD if heard else SEEN
	color = color.lerp(ANGRY, awareness * awareness)
	_glyph.text = "!" if fighting else "?"
	_glyph.modulate = ANGRY if fighting else color
	_material.set_shader_parameter("fill", 1.0 if fighting else awareness)
	_material.set_shader_parameter("color", ANGRY if fighting else color)
	_material.set_shader_parameter("pulse", 1.0 if fighting else 0.0)
