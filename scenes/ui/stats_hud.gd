class_name StatsHud
extends CanvasLayer
## Character HUD: a column of [StatBar]s in the top-left corner, always ordered health, mana,
## stamina however they are added. Add a bar once its system exists:
## [codeblock]
## var bar := hud.add_bar(StatBar.Kind.HEALTH)
## health_changed.connect(bar.set_value)
## [/codeblock]

const MARGIN := Vector2(28.0, 24.0)
const SPACING := 8

var _column := VBoxContainer.new()


func _ready() -> void:
	_column.add_theme_constant_override("separation", SPACING)
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.position = MARGIN
	add_child(_column)


func add_bar(kind: StatBar.Kind, fade_when_full := false) -> StatBar:
	var bar := StatBar.new()
	bar.kind = kind
	bar.fade_when_full = fade_when_full
	_column.add_child(bar)
	var slot := 0
	for other: StatBar in _column.get_children():
		if other != bar and other.kind < kind:
			slot += 1
	_column.move_child(bar, slot)
	return bar
