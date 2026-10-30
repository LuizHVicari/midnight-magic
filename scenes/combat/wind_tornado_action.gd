class_name WindTornadoAction
extends AbilityAction
## Tornado: calls a tornado where you aim. It pulls every walking creature near it in towards its
## middle and spins them there, bunching foes up for whatever comes next. It hardly hurts.

const MAX_REACH := 40.0
const DELAY := 0.2


func _cast() -> bool:
	if not caster.begin_cast(Player.ANIM_THROW, 0.0, 1.6):
		return false
	var spot := _spot()
	caster.get_tree().create_timer(DELAY).timeout.connect(func() -> void: _call(spot))
	return true


func _call(spot: Vector3) -> void:
	var tornado := WindTornado.new()
	tornado.element = element
	tornado.caster = caster
	tornado.position = spot
	caster.get_parent().add_child(tornado)


func _spot() -> Vector3:
	var aim := caster.aim_point()
	var away := aim - caster.global_position
	return aim if away.length() <= MAX_REACH else caster.global_position + away.normalized() * MAX_REACH
