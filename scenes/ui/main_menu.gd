class_name MainMenu
extends Control
## Title screen: Play, Credits, Quit. It draws its own night sky (a gradient, a crescent moon and
## twinkling stars) and uses the same wood-and-parchment look as the HUD bars. The game itself
## lives in [constant GAME_SCENE]; Play loads it.

const GAME_SCENE := "res://scenes/main.tscn"

const WOOD := Color("b97b5c")
const WOOD_LIGHT := Color("d19572")
const WOOD_DARK := Color("5b382c")
const PARCHMENT := Color("f6e8c8")
const SKY_TOP := Color("120c2e")
const SKY_BOTTOM := Color("3a2a63")
const STARS := 90

var _stars: Array[Vector3] = []  # x, y as a share of the screen, and a twinkle phase
var _menu := VBoxContainer.new()
var _credits := PanelContainer.new()
var _status := Label.new()
var _play: Button
var _time := 0.0
var _loading := false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 24
	for i in STARS:
		_stars.append(Vector3(rng.randf(), rng.randf() * 0.8, rng.randf() * TAU))
	_build_menu()
	_build_credits()
	_play.grab_focus()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _credits.visible:
		_show_credits(false)


func _draw() -> void:
	var area := get_viewport_rect().size
	var corners := PackedVector2Array([Vector2.ZERO, Vector2(area.x, 0.0), area, Vector2(0.0, area.y)])
	draw_polygon(corners, PackedColorArray([SKY_TOP, SKY_TOP, SKY_BOTTOM, SKY_BOTTOM]))
	for star in _stars:
		var glow := 0.55 + 0.45 * sin(_time * 1.6 + star.z)
		draw_circle(Vector2(star.x * area.x, star.y * area.y), 1.2 + glow * 1.2, Color(PARCHMENT, 0.35 + glow * 0.6))
	var moon := Vector2(area.x * 0.9, area.y * 0.16)
	var radius := minf(area.x, area.y) * 0.065
	draw_circle(moon, radius * 1.5, Color(PARCHMENT, 0.06))
	draw_circle(moon, radius, PARCHMENT)
	draw_circle(moon + Vector2(radius * 0.42, -radius * 0.18), radius * 0.92, SKY_TOP.lerp(SKY_BOTTOM, 0.2))


func _build_menu() -> void:
	var center := _full_screen_layout()
	_menu.add_theme_constant_override("separation", 16)
	_menu.custom_minimum_size = Vector2(340.0, 0.0)
	_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_menu)

	var title := Label.new()
	title.text = "Midnight Magic"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 84)
	title.add_theme_color_override("font_color", PARCHMENT)
	title.add_theme_color_override("font_outline_color", WOOD_DARK)
	title.add_theme_constant_override("outline_size", 16)
	_menu.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "a game by Luiz"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(PARCHMENT, 0.7))
	_menu.add_child(subtitle)
	_menu.add_child(Control.new())

	_play = _button("Play", _on_play)
	_button("Credits", func() -> void: _show_credits(true))
	if not OS.has_feature("web"):
		_button("Quit", func() -> void: get_tree().quit())

	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", PARCHMENT)
	_menu.add_child(_status)


func _build_credits() -> void:
	var center := _full_screen_layout()
	_credits.visible = false
	_credits.add_theme_stylebox_override("panel", _box(WOOD_DARK.darkened(0.2), WOOD, 14, 24))
	center.add_child(_credits)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	_credits.add_child(column)

	var heading := Label.new()
	heading.text = "Credits"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 40)
	heading.add_theme_color_override("font_color", PARCHMENT)
	column.add_child(heading)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(760.0, 400.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.text = Credits.bbcode()
	text.meta_clicked.connect(func(meta: Variant) -> void: OS.shell_open(str(meta)))
	scroll.add_child(text)

	var back := Button.new()
	back.text = "Back"
	_style(back)
	back.pressed.connect(func() -> void: _show_credits(false))
	column.add_child(back)


## A full-screen container that centers its child. It must ignore the mouse: two of them are
## stacked, and a container that catches clicks would hide the buttons of the one underneath.
func _full_screen_layout() -> CenterContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	return center


func _show_credits(on: bool) -> void:
	_credits.visible = on
	_menu.get_parent().visible = not on
	if on:
		_credits.find_children("*", "Button", true, false)[0].grab_focus()
	else:
		_play.grab_focus()


func _on_play() -> void:
	if _loading:
		return
	_loading = true
	_status.text = "Loading the world..."
	# Let the label appear before the (long) world generation freezes the window.
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().change_scene_to_file(GAME_SCENE)


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	_style(button)
	button.pressed.connect(action)
	_menu.add_child(button)
	return button


func _style(button: Button) -> void:
	button.custom_minimum_size = Vector2(0.0, 58.0)
	button.add_theme_font_size_override("font_size", 28)
	button.add_theme_color_override("font_color", PARCHMENT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _box(WOOD, WOOD_DARK, 12, 10))
	button.add_theme_stylebox_override("hover", _box(WOOD_LIGHT, WOOD_DARK, 12, 10))
	button.add_theme_stylebox_override("focus", _box(WOOD_LIGHT, PARCHMENT, 12, 10))
	button.add_theme_stylebox_override("pressed", _box(WOOD.darkened(0.2), WOOD_DARK, 12, 10))


func _box(fill: Color, border: Color, radius: int, margin: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(3)
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(margin)
	return box
