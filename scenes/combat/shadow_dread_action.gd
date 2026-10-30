class_name ShadowDreadAction
extends AbilityAction
## Dread: a wave of darkness bursts out of the hero. Every foe in reach is seized by terror and runs
## from the hero for a few seconds, attacking nothing, which breaks a group up. Heavy foes shake it
## off quickly. The hero's own screen fills with dense dark smoke for a moment. At night it
## reaches farther and lasts longer.

const RADIUS := Vector2(12.0, 16.0)  # by day, at night
const FEAR_TIME := Vector2(5.0, 7.0)
const DELAY := 0.15


func _cast() -> bool:
	if not caster.begin_cast(Player.ANIM_THROW, 0.0, 1.4):
		return false
	caster.get_tree().create_timer(DELAY).timeout.connect(_unleash)
	return true


func _unleash() -> void:
	var night := Combat.night_amount(caster.get_tree())
	var radius := lerpf(RADIUS.x, RADIUS.y, night)
	var effect := ShadowDread.new()
	effect.radius = radius
	effect.position = caster.global_position
	caster.get_parent().add_child(effect)
	(caster.get_node("Hud") as StatsHud).dread()
	caster.shake(0.18)
	for foe: Foe in caster.get_tree().get_nodes_in_group("foes"):
		if not foe.dead and foe.global_position.distance_to(caster.global_position) <= radius:
			foe.frighten(lerpf(FEAR_TIME.x, FEAR_TIME.y, night))
