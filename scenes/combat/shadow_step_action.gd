class_name ShadowStepAction
extends AbilityAction
## Shadow step: the hero melts into shadow and steps out at the spot they aim at, up to a few
## meters off, and nothing can touch them on the way. Aimed at a foe they come out right behind
## it, looking at its back. It stops short of walls. At night it reaches twice as far, comes back
## in half the time and leaves the hero quiet for a few seconds.

const RANGE := Vector2(10.0, 20.0)  # by day, at night
const MIN_DISTANCE := 2.0
const BEHIND := 1.7
const TIME := 0.16
const CLEARANCE := 0.45
const BODY_CENTER := 1.0
const NIGHT_COOLDOWN := 0.5  # share of the cooldown left at full night
const HUSH_TIME := 3.0
const HUSH_FROM := 0.3  # how much night it takes to leave the hero quiet
const TURN_TIME := 0.3


func _init() -> void:
	cooldown_on_cast = false  # it only starts if the step really happens, and is shorter at night


func _cast() -> bool:
	var night := Combat.night_amount(caster.get_tree())
	var plan := _plan(lerpf(RANGE.x, RANGE.y, night))
	if plan.is_empty():
		return false
	var from := caster.global_position
	if not caster.begin_dash(plan["to"], TIME):
		return false
	cooldown_left = ability.cooldown * lerpf(1.0, NIGHT_COOLDOWN, night)
	if night >= HUSH_FROM:
		caster.hush_left = HUSH_TIME
	var parent := caster.get_parent()
	ShadowVfx.vanish(parent, from + Vector3.UP * BODY_CENTER)
	var to: Vector3 = plan["to"]
	caster.get_tree().create_timer(TIME).timeout.connect(func() -> void: ShadowVfx.vanish(parent, to + Vector3.UP * BODY_CENTER))
	(caster.get_node("Hud") as StatsHud).dread(0.35, 0.7)
	if plan.has("face"):
		_turn_to(plan["face"])
	return true


## Where to end up, and which way to face afterwards if the step is aimed at a foe. Empty if
## there is nowhere to go.
func _plan(reach: float) -> Dictionary:
	var from := caster.global_position
	var camera := caster.camera
	var target := Combat.find_target(caster, camera.global_position, -camera.global_basis.z, reach + 8.0, 5.0)
	var body := target.get_parent() as Node3D if target != null else null
	if body != null and body.global_position.distance_to(from) <= reach + BEHIND:
		return _behind(body, from)
	var offset := caster.aim_point() - from
	offset.y = 0.0
	if offset.length() < MIN_DISTANCE:
		return {}
	var spot := _settle(from, offset.normalized(), minf(offset.length(), reach))
	return {} if spot == Vector3.INF else {"to": spot}


func _behind(body: Node3D, from: Vector3) -> Dictionary:
	var away := body.global_position - from
	away.y = 0.0
	if away.length() < 0.1:
		return {}
	away = away.normalized()
	var wanted := body.global_position + away * BEHIND - from
	wanted.y = 0.0
	var spot := _settle(from, wanted.normalized(), wanted.length())
	return {} if spot == Vector3.INF else {"to": spot, "face": away}


## The ground point [param distance] along [param direction] from [param from], held back from
## walls and put on the floor. Infinity if a wall leaves no room to go.
func _settle(from: Vector3, direction: Vector3, distance: float) -> Vector3:
	var exclude := Combat.creature_bodies(caster.get_tree())
	exclude.append(caster.get_rid())
	var free := Combat.free_distance(caster, from + Vector3.UP * BODY_CENTER, direction, distance, CLEARANCE, exclude) - 0.2
	if free < MIN_DISTANCE:
		return Vector3.INF
	var spot := from + direction * free
	var ground := Combat.raycast(caster, spot + Vector3.UP * 8.0, spot + Vector3.DOWN * 30.0, exclude)
	if not ground.is_empty():
		spot.y = ground["position"].y
	return spot


## Swings the camera round to look along [param direction], smoothly.
func _turn_to(direction: Vector3) -> void:
	var from := caster.camera_pivot.rotation.y
	var to := atan2(-direction.x, -direction.z)
	var tween := caster.create_tween()
	tween.tween_method(func(share: float) -> void: caster.camera_pivot.rotation.y = lerp_angle(from, to, share), 0.0, 1.0, TURN_TIME).set_ease(Tween.EASE_OUT)
