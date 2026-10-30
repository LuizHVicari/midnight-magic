class_name EarthShatterAction
extends AbilityAction
## Shatter: bursts every block of your stone within reach (pillars, walls, rubble and cocoons). Each
## one goes off in a spray of shards that hurts everything round it, the more the more it had left
## in it. Turns what you built into a weapon. Nothing happens, and nothing is spent, if there is no
## stone to burst.

const REACH := 40.0
const RADIUS := 4.5
const BASE_DAMAGE := 15.0
const PER_POINT := 0.8  # of the hit points still left in it
const EDGE := 0.3
const DELAY := 0.1


func _cast() -> bool:
	if _stones().is_empty():
		return false
	if not caster.begin_cast(Player.ANIM_THROW, 0.0, 2.2):
		return false
	caster.get_tree().create_timer(DELAY).timeout.connect(_burst)
	return true


func _stones() -> Array[Node]:
	var near: Array[Node] = []
	for stone: Node in caster.get_tree().get_nodes_in_group(StoneBlock.BLOCKS):
		if stone.has_method("blast_center") and stone.blast_center().distance_to(caster.global_position) <= REACH:
			near.append(stone)
	return near


func _burst() -> void:
	var parent := caster.get_parent()
	var exclude := StoneBlock.bodies(caster.get_tree())
	exclude.append(caster.get_rid())
	for stone in _stones():
		var center: Vector3 = stone.blast_center()
		var damage := BASE_DAMAGE + float(stone.remaining()) * PER_POINT
		stone.shatter()
		for health in Combat.blast(caster, center, RADIUS, damage, element, exclude, EDGE):
			health.stun(0.6, element)
		EarthVfx.dust(parent, center, RADIUS * 0.7)
		Vfx.sparks(parent, center, EarthVfx.TIP, 22)
		Vfx.flash(parent, center, Color(1.0, 0.75, 0.4), 4.5, 10.0, 0.25)
	caster.shake(0.2)
