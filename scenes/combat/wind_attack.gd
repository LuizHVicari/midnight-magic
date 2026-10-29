class_name WindAttack
extends SpellAttack
## Wind: a quick gust in a cone in front of the hero. Short reach, but it hits everything in
## the cone and throws it back, so it is the one for crowds and for making room.

const COST := 8.0
const THROW_SPEED := 2.2
const WINDUP := 0.14  # seconds into the animation when the gust leaves the wand


func begin() -> void:
	if caster.mana < COST or not caster.begin_cast(Player.ANIM_THROW, 0.0, THROW_SPEED):
		return
	caster.spend_mana(COST)
	await get_tree().create_timer(WINDUP).timeout
	_release_gust()


func _release_gust() -> void:
	var gust := WindGust.new()
	gust.element = element
	gust.caster = caster
	gust.direction = (caster.aim_point() - caster.cast_origin()).normalized()
	# Placed before it enters the tree: the gust reads where it starts from in _ready.
	gust.position = caster.cast_origin()
	caster.get_parent().add_child(gust)
