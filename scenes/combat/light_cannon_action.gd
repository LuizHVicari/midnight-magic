class_name LightCannonAction
extends AbilityAction
## Light cannon: the wand rises and energy gathers in a ball of light hovering to the hero's
## right, then a thick bolt leaves it at once and passes through the first few targets. Stronger than a lance
## and harder to dodge, but it has to be wound up first.

const WINDUP := 1.3
const BOLT_LOCK := 0.45
## Where the energy gathers, from the hero: to the right of the camera, a little ahead and up.
const BESIDE := 1.1
const AHEAD := 0.6
const HEIGHT := 1.6

var _charging := false
var _time := 0.0
var _charge: LightCharge


func _ready() -> void:
	_charge = LightCharge.new()
	_charge.top_level = true
	_charge.visible = false
	add_child(_charge)


func _cast() -> bool:
	if not caster.begin_cast(Player.ANIM_CHANNEL, INF, 1.0, Player.CHANNEL_HOLD):
		return false
	_charging = true
	_time = 0.0
	_charge.visible = true
	return true


func _update(delta: float) -> void:
	if not _charging:
		return
	_time += delta
	_charge.global_position = _anchor()
	_charge.set_charge(_time / WINDUP)
	if _time >= WINDUP:
		_fire()


## The spot beside the hero the ball swells at and the bolt leaves from.
func _anchor() -> Vector3:
	var yaw := caster.camera_pivot.rotation.y
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var ahead := Vector3(-sin(yaw), 0.0, -cos(yaw))
	return caster.global_position + right * BESIDE + ahead * AHEAD + Vector3.UP * HEIGHT


func _fire() -> void:
	_charging = false
	_charge.set_charge(0.0)
	_charge.visible = false
	caster.release_cast(Player.ANIM_THROW, BOLT_LOCK, 1.8)
	var origin := _anchor()
	var bolt := LightBolt.new()
	bolt.element = element
	bolt.caster = caster
	bolt.direction = (caster.aim_point() - origin).normalized()
	bolt.position = origin
	caster.get_parent().add_child(bolt)
