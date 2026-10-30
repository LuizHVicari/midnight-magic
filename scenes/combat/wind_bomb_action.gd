class_name WindBombAction
extends AbilityAction
## Wind bomb: throws a small ball of wind that goes off where it lands and throws everything near
## away, the hero too. Cheap and quick to throw again and again: aimed at the ground under you
## it lifts you, so a stream of bombs can hold you in the air and push you along.

const THROW_SPEED := 3.6
const LOCK := 0.2  # seconds before the next throw can start
const RELEASE := 0.05  # into the throw when the bomb leaves the wand


func _cast() -> bool:
	if not caster.begin_cast(Player.ANIM_THROW, LOCK, THROW_SPEED):
		return false
	caster.get_tree().create_timer(RELEASE).timeout.connect(_throw)
	return true


func _throw() -> void:
	var origin := caster.cast_origin()
	var bomb := WindBomb.new()
	bomb.element = element
	bomb.caster = caster
	bomb.direction = (caster.aim_point() - origin).normalized()
	bomb.position = origin
	caster.get_parent().add_child(bomb)
