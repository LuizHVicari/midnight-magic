class_name ShadowAttack
extends SpellAttack
## Shadow: casts a wisp of darkness that homes in and curses its target. A quick, cheap cast,
## so the way to use it is to keep it coming: curses stack and wear the target down.

const COST := 9.0
const THROW_SPEED := 1.8
const WINDUP := 0.22  # seconds into the animation when the wisp leaves the wand


func begin() -> void:
	if caster.mana < COST or not caster.begin_cast(Player.ANIM_THROW, 0.0, THROW_SPEED):
		return
	caster.spend_mana(COST)
	await get_tree().create_timer(WINDUP).timeout
	_launch()


func _launch() -> void:
	var wisp := ShadowWisp.new()
	wisp.element = element
	wisp.caster = caster
	wisp.direction = (caster.aim_point() - caster.cast_origin()).normalized()
	# Placed before it enters the tree: the wisp reads where it starts from in _ready.
	wisp.position = caster.cast_origin()
	caster.get_parent().add_child(wisp)
