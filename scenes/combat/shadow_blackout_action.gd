class_name ShadowBlackoutAction
extends AbilityAction
## Blackout: spreads a zone of living darkness where you aim. For a good while, foes in it or
## looking at a hero in it see only a fifth as far, and the hero's own screen darkens at the edges
## so you know you are inside. It does no harm. At night it is wider and lasts longer. A hero who
## gives off light (an orb, a flash) is only half hidden.

const MAX_REACH := 40.0
const DELAY := 0.2
const RADIUS := Vector2(9.0, 11.0)  # by day, at night
const DURATION := Vector2(25.0, 40.0)


func _cast() -> bool:
	if not caster.begin_cast(Player.ANIM_THROW, 0.0, 1.6):
		return false
	var aim := caster.aim_point()
	var away := aim - caster.global_position
	var spot := aim if away.length() <= MAX_REACH else caster.global_position + away.normalized() * MAX_REACH
	caster.get_tree().create_timer(DELAY).timeout.connect(func() -> void: _spread(spot))
	return true


func _spread(spot: Vector3) -> void:
	var night := Combat.night_amount(caster.get_tree())
	var zone := BlackoutZone.new()
	zone.radius = lerpf(RADIUS.x, RADIUS.y, night)
	zone.duration = lerpf(DURATION.x, DURATION.y, night)
	zone.position = spot
	caster.get_parent().add_child(zone)
