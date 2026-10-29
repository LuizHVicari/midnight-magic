class_name ProgressBadge
extends Control
## Level, experience and coins, drawn under the stat bars: a gold "Lv N" medallion, a thin
## experience bar and a coin counter. Same wood and parchment look as the bars.

const WOOD := Color("b97b5c")
const WOOD_DARK := Color("5b382c")
const TROUGH := Color("2f2120")
const PARCHMENT := Color("f6e8c8")
const GOLD := Color("f2c14e")
const XP := Color("7fd3c8")

var _level := 1
var _xp := 0.0
var _xp_next := 1.0
var _coins := 0
var _shown_xp := 0.0
var _flash := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(300.0, 56.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_level(level: int, leveled_up := false) -> void:
	_level = level
	_flash = 1.0 if leveled_up else _flash
	queue_redraw()


func set_xp(value: float, needed: float) -> void:
	_xp = value
	_xp_next = maxf(needed, 1.0)


func set_coins(coins: int) -> void:
	_coins = coins
	queue_redraw()


func _process(delta: float) -> void:
	_shown_xp = lerpf(_shown_xp, _xp, 1.0 - exp(-8.0 * delta))
	_flash = maxf(_flash - delta * 0.8, 0.0)
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var medallion := Vector2(18.0, 18.0)
	draw_circle(medallion, 17.0, WOOD_DARK)
	draw_circle(medallion, 14.5, WOOD.lerp(GOLD, _flash))
	draw_string(font, medallion + Vector2(-9.0, 6.0), str(_level), HORIZONTAL_ALIGNMENT_CENTER, 18.0, 17, PARCHMENT)
	draw_string(font, Vector2(44.0, 14.0), "Level %d" % _level, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, PARCHMENT)

	var bar := Rect2(44.0, 20.0, 236.0, 8.0)
	draw_rect(bar.grow(2.0), WOOD_DARK)
	draw_rect(bar, TROUGH)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(_shown_xp / _xp_next, 0.0, 1.0), bar.size.y)), XP)

	var coin := Vector2(52.0, 44.0)
	var points := PackedVector2Array([coin + Vector2(0.0, -7.0), coin + Vector2(6.0, 0.0), coin + Vector2(0.0, 7.0), coin + Vector2(-6.0, 0.0)])
	draw_colored_polygon(points, GOLD)
	draw_polyline(points + PackedVector2Array([points[0]]), WOOD_DARK, 1.5)
	draw_string(font, Vector2(66.0, 49.0), str(_coins), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, PARCHMENT)
