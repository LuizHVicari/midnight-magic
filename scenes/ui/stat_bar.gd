class_name StatBar
extends Control
## One gauge of the character HUD (health, mana, stamina), drawn in code in the same flat,
## chunky style as the world: terracotta wood frame like the house beams, a dark trough, a
## flat pastel fill with a soft highlight and a round medallion holding the stat's icon.
## A pale ghost trails behind the fill when the value drops. Optionally fades while full.

enum Kind { HEALTH, MANA, STAMINA }

const BAR_SIZE := Vector2(270.0, 32.0)
const CENTER_Y := 16.0
const MEDALLION := Vector2(16.0, CENTER_Y)
const MEDALLION_RADIUS := 15.0
const FRAME := Rect2(18.0, 6.0, 252.0, 20.0)
const FILL := Rect2(32.0, 9.5, 234.0, 13.0)

const WOOD := Color("b97b5c")
const WOOD_DARK := Color("5b382c")
const TROUGH := Color("2f2120")
const PARCHMENT := Color("f6e8c8")
const GHOST := Color(1.0, 1.0, 1.0, 0.5)

## Per stat: normal fill, highlight, and the color it turns when low or depleted.
const PALETTE := {
	Kind.HEALTH: {"fill": Color("e4605a"), "light": Color("f9958a"), "low": Color("a8322d")},
	Kind.MANA: {"fill": Color("5b8fe6"), "light": Color("94bbf8"), "low": Color("6a5acd")},
	Kind.STAMINA: {"fill": Color("86c85a"), "light": Color("bbe88a"), "low": Color("eba944")},
}

const LOW_AT := 0.25
const FADE_AFTER := 1.5
const IDLE_ALPHA := 0.45

@export var kind := Kind.STAMINA
## Fade the gauge out while the value is full, so it only shows when it matters.
@export var fade_when_full := false

var _fraction := 1.0
var _depleted := false
var _shown := 1.0
var _ghost := 1.0
var _full_time := 0.0
var _box := StyleBoxFlat.new()


func _init() -> void:
	custom_minimum_size = BAR_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.anti_aliasing = true


## [depleted] marks the "ran dry" state (stamina exhaustion): the gauge pulses.
func set_value(value: float, maximum: float, depleted := false) -> void:
	_fraction = clampf(value / maximum, 0.0, 1.0)
	_depleted = depleted


func _process(delta: float) -> void:
	_shown = lerpf(_shown, _fraction, 1.0 - exp(-18.0 * delta))
	# The ghost waits where the bar was and slides down after it; refills move it at once.
	_ghost = _fraction if _fraction > _ghost else lerpf(_ghost, _fraction, 1.0 - exp(-2.5 * delta))

	var resting := fade_when_full and _fraction > 0.999 and not _depleted
	_full_time = _full_time + delta if resting else 0.0
	var alpha := IDLE_ALPHA if _full_time > FADE_AFTER else 1.0
	modulate.a = lerpf(modulate.a, alpha, 1.0 - exp(-4.0 * delta))
	queue_redraw()


func _draw() -> void:
	var colors: Dictionary = PALETTE[kind]
	_round_rect(FRAME, TROUGH, 10.0, 3.0, WOOD, 4)
	_draw_band(_ghost, GHOST, Color.TRANSPARENT)
	_draw_band(_shown, _fill_color(colors), colors["light"])
	_draw_medallion(colors)


func _fill_color(colors: Dictionary) -> Color:
	if _depleted:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
		return (colors["low"] as Color).lerp(Color.WHITE, pulse * 0.3)
	return (colors["fill"] as Color).lerp(colors["low"], 1.0 - smoothstep(0.1, LOW_AT, _fraction))


func _draw_band(fraction: float, color: Color, light: Color) -> void:
	if fraction <= 0.004:
		return
	var width := maxf(FILL.size.x * fraction, 4.0)
	var rect := Rect2(FILL.position, Vector2(width, FILL.size.y))
	_round_rect(rect, color, 6.0)
	if light.a > 0.0:
		var strip := Rect2(rect.position + Vector2(2.0, 1.5), Vector2(maxf(width - 4.0, 0.0), 3.5))
		_round_rect(strip, Color(light, 0.75), 2.0)


func _draw_medallion(colors: Dictionary) -> void:
	draw_circle(MEDALLION + Vector2(0.0, 2.0), MEDALLION_RADIUS + 1.0, Color(0.0, 0.0, 0.0, 0.28))
	draw_circle(MEDALLION, MEDALLION_RADIUS, WOOD_DARK)
	draw_circle(MEDALLION, MEDALLION_RADIUS - 2.0, WOOD)
	draw_circle(MEDALLION, MEDALLION_RADIUS - 5.0, (colors["fill"] as Color).darkened(0.25))
	draw_colored_polygon(_icon(MEDALLION, 6.5), PARCHMENT)


func _icon(center: Vector2, size: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	match kind:
		Kind.HEALTH:
			for k in 28:
				var t := TAU * k / 28.0
				var x := 16.0 * pow(sin(t), 3.0)
				var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
				points.append(center + Vector2(x, y + 1.0) / 17.0 * size)
		Kind.MANA:
			# Five-point star, point up.
			for k in 10:
				var radius := 1.2 if k % 2 == 0 else 0.5
				var angle := -PI * 0.5 + TAU * k / 10.0
				points.append(center + Vector2(cos(angle), sin(angle)) * radius * size)
		Kind.STAMINA:
			for p in [Vector2(0.25, -1.0), Vector2(-0.6, 0.1), Vector2(-0.05, 0.1), Vector2(-0.3, 1.0), Vector2(0.6, -0.2), Vector2(0.05, -0.2)]:
				points.append(center + p * size)
	return points


func _round_rect(rect: Rect2, color: Color, radius: float, border := 0.0, border_color := Color.TRANSPARENT, shadow := 0) -> void:
	_box.bg_color = color
	_box.set_corner_radius_all(int(minf(radius, minf(rect.size.x, rect.size.y) * 0.5)))
	_box.set_border_width_all(int(border))
	_box.border_color = border_color
	_box.shadow_size = shadow
	_box.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
	_box.shadow_offset = Vector2(0.0, 2.0)
	draw_style_box(_box, rect)
