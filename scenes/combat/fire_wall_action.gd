class_name FireWallAction
extends AbilityAction
## Fire wall: raises a wall of flame across the way you are aiming, where you aim. It burns
## anything that stands in it and foes walk round it, so it makes a barrier as well as a trap.

const MAX_REACH := 35.0
const DELAY := 0.2


func _cast() -> bool:
	if not caster.begin_cast(Player.ANIM_THROW, 0.0, 1.6):
		return false
	var aim := caster.aim_point()
	var away := aim - caster.global_position
	away.y = 0.0
	var spot := aim if away.length() <= MAX_REACH else caster.global_position + away.normalized() * MAX_REACH
	var heading := away.normalized() if away.length() > 0.1 else Vector3.FORWARD
	var along := heading.cross(Vector3.UP).normalized()
	caster.get_tree().create_timer(DELAY).timeout.connect(func() -> void: _raise(spot, along))
	return true


func _raise(spot: Vector3, along: Vector3) -> void:
	var wall := FireWall.new()
	wall.element = element
	wall.caster = caster
	wall.along = along
	wall.position = spot
	caster.get_parent().add_child(wall)
