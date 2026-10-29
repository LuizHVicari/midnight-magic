class_name GroundAnimal
extends Animal
## A land animal: stands around, wanders near its home, sometimes grazes, and runs when scared.
## Skittish species run from the hero as soon as they see or hear them; passive ones only once
## they are hurt. It never walks into water or up cliffs: it looks at the terrain ahead and
## turns away. The behavior is a small state machine:
## [codeblock]
## IDLE --(timer)--> WANDER / GRAZE / IDLE
## WANDER --(arrived or timer)--> IDLE
## any --(scared)--> FLEE --(far enough and calm)--> IDLE
## [/codeblock]

enum State { IDLE, WANDER, GRAZE, FLEE }

const ARRIVE := 1.2  # meters from the goal that count as arrived
const STUCK_TIME := 1.0
const LOOKAHEAD := 1.8

var state := State.IDLE

var _state_left := 0.0
var _goal := Vector3.ZERO
var _flee_dir := Vector3.ZERO
var _stuck := 0.0


func _ready() -> void:
	super._ready()
	_enter(State.IDLE)


func _think(delta: float) -> void:
	if state != State.FLEE and _is_scared():
		_enter(State.FLEE)
	_state_left -= delta
	match state:
		State.IDLE:
			_idle(delta)
		State.WANDER:
			_wander(delta)
		State.GRAZE:
			_graze(delta)
		State.FLEE:
			_flee(delta)


func _is_scared() -> bool:
	if _provoked > 0.0:
		return true
	return species.temperament == Species.Temperament.SKITTISH and (sees_player or hears_player)


func _enter(next: State) -> void:
	state = next
	_stuck = 0.0
	match next:
		State.IDLE:
			_state_left = _rng.randf_range(2.0, 5.0)
			play("look" if has_animation("look") and _rng.randf() < 0.3 else "idle")
		State.WANDER:
			_state_left = _rng.randf_range(4.0, 9.0)
			_goal = _pick_goal()
		State.GRAZE:
			_state_left = _rng.randf_range(3.0, 6.0)
			play("eat")
		State.FLEE:
			_state_left = 0.0
			_flee_dir = _away_from_threat()


func _idle(delta: float) -> void:
	_move(Vector3.ZERO, 0.0, delta)
	if _state_left > 0.0:
		return
	var roll := _rng.randf()
	if roll < 0.55:
		_enter(State.WANDER)
	elif has_animation("eat") and roll < 0.85:
		_enter(State.GRAZE)
	else:
		_enter(State.IDLE)


func _wander(delta: float) -> void:
	var to_goal := _goal - global_position
	to_goal.y = 0.0
	var speed := _move(_steer(to_goal.normalized()), species.walk_speed, delta)
	play("walk")
	_stuck = _stuck + delta if speed < species.walk_speed * 0.25 else 0.0
	if to_goal.length() < ARRIVE or _state_left <= 0.0 or _stuck > STUCK_TIME:
		_enter(State.IDLE)


func _graze(delta: float) -> void:
	_move(Vector3.ZERO, 0.0, delta)
	if _state_left <= 0.0:
		_enter(State.IDLE)


func _flee(delta: float) -> void:
	_flee_dir = _away_from_threat()
	_move(_steer(_flee_dir), species.run_speed, delta)
	play("run")
	var far := Vector2(global_position.x - _threat.x, global_position.z - _threat.z).length() > species.safe_distance
	if far and _alerted <= 0.0 and _provoked <= 0.0:
		_enter(State.IDLE)


func _on_hurt() -> void:
	if not dead and state != State.FLEE:
		_enter(State.FLEE)


# --- movement ----------------------------------------------------------------------------------

## Moves along [param direction] (flat) at [param speed], faces it, and returns the speed reached.
func _move(direction: Vector3, speed: float, delta: float) -> float:
	var wanted := direction * speed * health.speed_factor()
	velocity.x = move_toward(velocity.x, wanted.x, 40.0 * delta) + _knock.x * delta * 8.0
	velocity.z = move_toward(velocity.z, wanted.z, 40.0 * delta) + _knock.z * delta * 8.0
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	face(direction, delta)
	move_and_slide()
	return Vector2(get_real_velocity().x, get_real_velocity().z).length()


func _away_from_threat() -> Vector3:
	var away := global_position - _threat
	away.y = 0.0
	if away.length() < 0.1:
		away = -_facing()
	return away.normalized()


func _pick_goal() -> Vector3:
	for attempt in 6:
		var angle := _rng.randf() * TAU
		var spot := home + Vector3(cos(angle), 0.0, sin(angle)) * _rng.randf_range(2.0, species.home_radius)
		if _walkable(spot):
			return spot
	return home


## Turns [param direction] aside until the ground ahead is dry and not too steep.
func _steer(direction: Vector3) -> Vector3:
	for turn in [0.0, 0.7, -0.7, 1.4, -1.4]:
		var candidate := direction.rotated(Vector3.UP, turn)
		if _walkable(global_position + candidate * LOOKAHEAD):
			return candidate
	return Vector3.ZERO


func _walkable(spot: Vector3) -> bool:
	var terrain := get_terrain()
	if terrain == null:
		return true
	return terrain.in_bounds(spot.x, spot.z, 8.0) and not terrain.is_water(spot.x, spot.z) and terrain.normal_at(spot.x, spot.z).y > 0.72
