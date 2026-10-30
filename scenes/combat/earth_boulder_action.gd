class_name EarthBoulderAction
extends AbilityAction
## Boulder: hurls a great rock in an arc at the spot you aim at. Where it lands it hits hard in a
## wide circle, stuns, and leaves rubble behind as cover. Slow to throw and costly: the heavy hitter
## of earth.

const MAX_REACH := 45.0
const FLIGHT := Vector2(0.5, 1.5)  # fastest and slowest trip, in seconds
const SPEED := 26.0
const WINDUP := 0.45  # into the throw when the rock leaves the hand


func _cast() -> bool:
	if not caster.begin_cast(Player.ANIM_THROW, 0.0, 1.0):
		return false
	var aim := caster.aim_point()
	var away := aim - caster.global_position
	var spot := aim if away.length() <= MAX_REACH else caster.global_position + away.normalized() * MAX_REACH
	caster.get_tree().create_timer(WINDUP).timeout.connect(func() -> void: _throw(spot))
	return true


func _throw(spot: Vector3) -> void:
	var origin := caster.cast_origin()
	var trip := clampf(origin.distance_to(spot) / SPEED, FLIGHT.x, FLIGHT.y)
	var rock := EarthBoulder.new()
	rock.element = element
	rock.caster = caster
	# Aimed so that it arrives at the spot after [trip] seconds, whatever gravity does to it.
	rock.velocity = (spot - origin) / trip + Vector3.UP * 0.5 * EarthBoulder.GRAVITY * trip
	rock.position = origin
	caster.get_parent().add_child(rock)
