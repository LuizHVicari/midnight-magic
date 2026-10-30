class_name WindUpdraftAction
extends AbilityAction
## Updraft: raises a column of rising air where you aim. Anything that walks and stands in it is
## carried up, so it is a lift for the hero (and a launch pad for gliding) and a way to throw foes
## into the air, helpless, to fall back down hurt.

const MAX_REACH := 40.0
const DELAY := 0.2  # lets the arm come up before the column rises


func _cast() -> bool:
	if not caster.begin_cast(Player.ANIM_THROW, 0.0, 1.6):
		return false
	var spot := _spot()
	caster.get_tree().create_timer(DELAY).timeout.connect(func() -> void: _raise(spot))
	return true


func _raise(spot: Vector3) -> void:
	var column := WindUpdraft.new()
	column.element = element
	column.caster = caster
	column.position = spot
	caster.get_parent().add_child(column)


func _spot() -> Vector3:
	var aim := caster.aim_point()
	var away := aim - caster.global_position
	return aim if away.length() <= MAX_REACH else caster.global_position + away.normalized() * MAX_REACH
