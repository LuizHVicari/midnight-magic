class_name ShadowDecoyAction
extends AbilityAction
## Shadow decoy: puts a copy of yourself made of shadow where you aim. Foes that are not fighting
## come to look at it and keep coming back, so it draws them off. It lasts a while, longer at
## night, when it also calls from farther.

const MAX_REACH := 40.0
const DELAY := 0.2
const DURATION := Vector2(10.0, 16.0)  # by day, at night
const LURE_REACH := Vector2(28.0, 50.0)


func _cast() -> bool:
	if not caster.begin_cast(Player.ANIM_THROW, 0.0, 1.8):
		return false
	var aim := caster.aim_point()
	var away := aim - caster.global_position
	var spot := aim if away.length() <= MAX_REACH else caster.global_position + away.normalized() * MAX_REACH
	var facing := Vector3(-sin(caster.camera_pivot.rotation.y), 0.0, -cos(caster.camera_pivot.rotation.y))
	caster.get_tree().create_timer(DELAY).timeout.connect(func() -> void: _form(spot, facing))
	return true


func _form(spot: Vector3, facing: Vector3) -> void:
	var night := Combat.night_amount(caster.get_tree())
	var decoy := ShadowDecoy.new()
	decoy.reach = lerpf(LURE_REACH.x, LURE_REACH.y, night)
	decoy.duration = lerpf(DURATION.x, DURATION.y, night)
	decoy.facing = facing
	decoy.position = spot
	caster.get_parent().add_child(decoy)
