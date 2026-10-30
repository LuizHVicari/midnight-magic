class_name ShadowVeil
extends ColorRect
## The screen treatment of the shadow spells: while the hero stands inside a blackout the edges
## of the screen close in with dark smoke and the colors drain a little, with the middle left
## clear; a dread burst does the same, much denser, and fades away. Invisible and free when idle.

const SHADER := preload("res://assets/shaders/dark_veil.gdshader")
const FADE_RATE := 1.1  # per second, going in and out of a blackout

var _material := ShaderMaterial.new()
var _inside := false
var _dark := 0.0
var _dread := 0.0
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material.shader = SHADER
	material = _material
	visible = false
	# A CanvasLayer is no Control, so there is no parent rect to anchor to: follow the window.
	_fit()
	get_viewport().size_changed.connect(_fit)


## Whether the hero is standing inside a blackout right now.
func set_inside(on: bool) -> void:
	_inside = on


## A burst of dread at [param strength] (0..1) that builds in a moment and fades over [param time].
func pulse(strength: float, time: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_dread, _dread, clampf(strength, 0.0, 1.0), 0.18).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(time * 0.25)
	_tween.tween_method(_set_dread, clampf(strength, 0.0, 1.0), 0.0, time * 0.75).set_ease(Tween.EASE_IN_OUT)


func _process(delta: float) -> void:
	_dark = move_toward(_dark, 1.0 if _inside else 0.0, FADE_RATE * delta)
	visible = _dark > 0.001 or _dread > 0.001
	if not visible:
		return
	_material.set_shader_parameter("darkness", _dark)
	_material.set_shader_parameter("dread", _dread)


func _set_dread(value: float) -> void:
	_dread = value


func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
