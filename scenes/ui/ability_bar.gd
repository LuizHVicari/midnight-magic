class_name AbilityBar
extends Control
## The hero's quick slots, along the bottom of the screen: one square per slot showing the
## ability's initial in its element's color, the key that fires it, a clock sweeping away while it
## recharges and a dimmer when there is not enough mana. It follows the equipped element, so
## switching element swaps the squares.

const SLOT := 60.0
const GAP := 10.0
const PRIMARY_GAP := 26.0  # extra room between the primary button and the keys
const MARGIN_BOTTOM := 28.0
const TROUGH := Color("2f2120")
const WOOD := Color("b97b5c")
const WOOD_DARK := Color("5b382c")
const PARCHMENT := Color("f6e8c8")
const SHADE := Color(0.05, 0.03, 0.08, 0.72)
const NO_MANA := Color(0.2, 0.3, 0.7, 0.35)

var player: Player

var _keys: PackedStringArray = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for action in Player.SLOT_ACTIONS:
		_keys.append(_key_label(action))


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if player == null or player.current_element == null:
		return
	var view := get_viewport_rect().size
	var count := Player.SLOT_ACTIONS.size()
	var width := count * SLOT + (count - 1) * GAP + PRIMARY_GAP
	var origin := Vector2((view.x - width) * 0.5, view.y - MARGIN_BOTTOM - SLOT).round()
	for slot in count:
		var shift := slot * (SLOT + GAP) + (PRIMARY_GAP if slot > 0 else 0.0)
		_draw_slot(Rect2(origin + Vector2(shift, 0.0), Vector2.ONE * SLOT), slot)


func _draw_slot(rect: Rect2, slot: int) -> void:
	var ability := player.slot_ability(slot)
	var accent := player.current_element.color
	_frame(rect, WOOD if ability != null else WOOD_DARK)
	var font := ThemeDB.fallback_font
	if ability != null:
		_draw_picture(rect, ability, accent)
		_draw_state(rect, ability)
	draw_string(font, rect.position + Vector2(6.0, 15.0), _keys[slot], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, PARCHMENT)


## The ability's icon, or the initial of its name until it has one.
func _draw_picture(rect: Rect2, ability: Ability, accent: Color) -> void:
	if ability.icon != null:
		draw_texture_rect(ability.icon, rect.grow(-5.0), false)
		return
	var font := ThemeDB.fallback_font
	var letter := ability.display_name.get_slice(" ", ability.display_name.get_slice_count(" ") - 1).substr(0, 1)
	var size := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_CENTER, -1, 30)
	draw_string(font, rect.get_center() + Vector2(-size.x * 0.5, 10.0), letter, HORIZONTAL_ALIGNMENT_CENTER, -1, 30, accent)


## The recharge clock and the not-enough-mana dimmer.
func _draw_state(rect: Rect2, ability: Ability) -> void:
	var action := player.ability_action(ability)
	var inner := rect.grow(-3.0)
	if action != null and action.gauge() >= 0.0:
		_draw_gauge(inner, action.gauge())
	if player.mana < ability.cost:
		draw_rect(inner, NO_MANA)
	if action == null or action.cooldown_left <= 0.0:
		return
	var share := action.cooldown_left / ability.cooldown
	draw_colored_polygon(_sweep(inner, share), SHADE)
	var seconds := "%.1f" % action.cooldown_left if action.cooldown_left < 10.0 else "%d" % ceili(action.cooldown_left)
	var font := ThemeDB.fallback_font
	var size := font.get_string_size(seconds, HORIZONTAL_ALIGNMENT_CENTER, -1, 18)
	draw_string(font, rect.get_center() + Vector2(-size.x * 0.5, 7.0), seconds, HORIZONTAL_ALIGNMENT_CENTER, -1, 18, PARCHMENT)


## The part of [param inner] still shaded: a wedge from the top going clockwise, [param share]
## of the full turn, clipped to the square.
func _sweep(inner: Rect2, share: float) -> PackedVector2Array:
	var center := inner.get_center()
	var points := PackedVector2Array([center])
	var steps := maxi(int(share * 48.0), 1)
	for i in steps + 1:
		var angle := -PI / 2.0 + TAU * share * float(i) / float(steps)
		var ray := Vector2(cos(angle), sin(angle))
		var reach := inner.size.x * 0.5 / maxf(absf(ray.x), absf(ray.y))
		points.append(center + ray * reach)
	return points


## A thin bar along the bottom of the slot, yellow when low and red as it fills.
func _draw_gauge(inner: Rect2, share: float) -> void:
	var bar := Rect2(inner.position + Vector2(0.0, inner.size.y - 6.0), Vector2(inner.size.x, 6.0))
	draw_rect(bar, Color(0.05, 0.03, 0.08, 0.85))
	var fill := Rect2(bar.position, Vector2(bar.size.x * clampf(share, 0.0, 1.0), bar.size.y))
	draw_rect(fill, Color(1.0, 0.85, 0.3).lerp(Color(0.95, 0.15, 0.1), share))


func _frame(rect: Rect2, wood: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = TROUGH
	box.border_color = wood
	box.set_border_width_all(3)
	box.set_corner_radius_all(8)
	box.anti_aliasing = true
	draw_style_box(box, rect)


func _key_label(action: String) -> String:
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return ""
	var mouse := events[0] as InputEventMouseButton
	if mouse != null:
		return "M%d" % mouse.button_index
	return (events[0] as InputEventKey).as_text_physical_keycode()
