class_name HitFlash
extends ColorRect
## Red vignette that flashes when the hero takes a hit and fades out again.

const FADE_TIME := 0.55

var _material := ShaderMaterial.new()
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material.shader = preload("res://assets/shaders/hit_flash.gdshader")
	material = _material
	# A CanvasLayer is no Control, so there is no parent rect to anchor to: follow the window.
	_fit()
	get_viewport().size_changed.connect(_fit)


## Flashes at [param strength] (0..1) and fades back out.
func pulse(strength: float) -> void:
	if _tween:
		_tween.kill()
	_material.set_shader_parameter("strength", clampf(strength, 0.0, 1.0))
	_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_tween.tween_method(_set_strength, clampf(strength, 0.0, 1.0), 0.0, FADE_TIME)


func _set_strength(value: float) -> void:
	_material.set_shader_parameter("strength", value)


func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
