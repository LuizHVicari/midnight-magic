class_name FireMeteorAction
extends AbilityAction
## Meteor: calls a meteor down where you aim. A circle of fire marks the spot at once, and about
## a second and a half later the meteor lands: a big, hard hit over a wide area that sets
## everything in it alight and leaves the ground burning. Slow to land and slow to come back.

const MAX_REACH := 45.0
const DELAY := 0.25  # lets the arm come up first


func _cast() -> bool:
	if not caster.begin_cast(Player.ANIM_THROW, 0.0, 1.3):
		return false
	var aim := caster.aim_point()
	var away := aim - caster.global_position
	var spot := aim if away.length() <= MAX_REACH else caster.global_position + away.normalized() * MAX_REACH
	caster.get_tree().create_timer(DELAY).timeout.connect(func() -> void: _call(spot))
	return true


func _call(spot: Vector3) -> void:
	var parent := caster.get_parent()
	var reticle := LightReticle.new()
	reticle.set_color(Color(1.0, 0.45, 0.12))
	reticle.set_radius(FireMeteor.RADIUS)
	reticle.position = spot
	parent.add_child(reticle)
	var slant := (spot - caster.global_position) * Vector3(1.0, 0.0, 1.0)
	var heading := slant.normalized() if slant.length() > 0.5 else Vector3.FORWARD
	var meteor := FireMeteor.new()
	meteor.element = element
	meteor.caster = caster
	meteor.target = spot
	meteor.direction = (heading * 0.55 + Vector3.DOWN * 0.84).normalized()
	meteor.reticle = reticle
	parent.add_child(meteor)
