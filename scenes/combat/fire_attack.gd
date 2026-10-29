class_name FireAttack
extends SpellAttack
## Fire: a heavy fireball shot from the wand. One at a time, costs a lot of mana and the
## throwing animation is the cooldown.

const COST := 20.0
const THROW_SPEED := 1.3
const WINDUP := 0.42  # seconds into the animation when the fireball leaves the wand


func begin() -> void:
	if caster.mana < COST or not caster.begin_cast(Player.ANIM_THROW, 0.0, THROW_SPEED):
		return
	caster.spend_mana(COST)
	await get_tree().create_timer(WINDUP).timeout
	_launch()


func _launch() -> void:
	var ball := Fireball.new()
	ball.element = element
	ball.caster = caster
	ball.direction = (caster.aim_point() - caster.cast_origin()).normalized()
	# Placed before it enters the tree: the fireball reads where it starts from in _ready.
	ball.position = caster.cast_origin()
	caster.get_parent().add_child(ball)
