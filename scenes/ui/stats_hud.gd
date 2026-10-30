class_name StatsHud
extends CanvasLayer
## Character HUD: a column of [StatBar]s in the top-left corner, always ordered health, mana,
## stamina however they are added, and the [Crosshair] in the middle of the screen. Add a bar once its system exists:
## [codeblock]
## var bar := hud.add_bar(StatBar.Kind.HEALTH)
## health_changed.connect(bar.set_value)
## [/codeblock]

const MARGIN := Vector2(28.0, 24.0)
const SPACING := 8

var _badge: ProgressBadge
var _flash := HitFlash.new()
var _veil := ShadowVeil.new()

var _column := VBoxContainer.new()


func _ready() -> void:
	add_child(_veil)  # first, so it sits under the bars and the crosshair
	_column.add_theme_constant_override("separation", SPACING)
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.position = MARGIN
	add_child(_column)
	add_child(Crosshair.new())
	add_child(_flash)


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


## The quick-slot bar for the hero's abilities, at the bottom of the screen.
func show_abilities(player: Player) -> void:
	var bar := AbilityBar.new()
	bar.player = player
	add_child(bar)


## Whether the hero is inside a blackout: the screen darkens round the edges.
func set_darkness(on: bool) -> void:
	_veil.set_inside(on)


## A burst of dread over the screen: dense dark smoke closing in, then fading.
func dread(strength := 1.0, time := 3.2) -> void:
	_veil.pulse(strength, time)


## The level, experience and coins panel under the bars; created on first use.
func badge() -> ProgressBadge:
	if _badge == null:
		_badge = ProgressBadge.new()
		_column.add_child(_badge)
	return _badge


## Flashes the screen edges red (or [param color]); [param strength] is 0..1. With [param fill]
## at 1 the whole screen goes, for a flash of light.
func flash(strength: float, color := HitFlash.RED, fill := 0.0, time := HitFlash.FADE_TIME) -> void:
	_flash.pulse(strength, color, fill, time)
