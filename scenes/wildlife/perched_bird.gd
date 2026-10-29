class_name PerchedBird
extends Animal
## A bird that lives in the trees: owls and small birds. It sits on a perch in a tree crown, and
## when the hero comes close (nearer when the hero is quiet) or something hurts it, it flies to
## another tree far from the danger and lands there. Birds of a flock raise the alarm together.
## Owls sleep through the day, until you are near, and are awake at night. Set [member perch] before adding it to the tree.
## [codeblock]
## PERCHED --(hero near / hurt / flock alarm)--> FLYING --(arrived)--> LANDING --> PERCHED
## PERCHED --(now and then, birds only)--> FLYING to a nearby tree
## [/codeblock]

enum State { PERCHED, FLYING, LANDING }

const LAND_TIME := 0.7
const HOP_EVERY := Vector2(25.0, 70.0)
const FLEE_REACH := Vector2(45.0, 90.0)
const KNOCKED_OFF := 0.8  # meters from its perch that count as having been knocked off it
const ALARM_RADIUS := 30.0

var perch := Vector3.ZERO
## The birds it flies with: they take off together.
var flock: Array[PerchedBird] = []
var state := State.PERCHED

var _start := Vector3.ZERO
var _target := Vector3.ZERO
var _progress := 0.0
var _distance := 1.0
var _arc := 3.0
var _state_left := 0.0
var _hop_left := 0.0
var _alarm_left := -1.0


func _ready() -> void:
	home = perch
	super._ready()
	global_position = perch
	_hop_left = _rng.randf_range(HOP_EVERY.x, HOP_EVERY.y)
	_settle(_rng.randf() * TAU)


func _think(delta: float) -> void:
	match state:
		State.PERCHED:
			_perched(delta)
		State.FLYING:
			_flying(delta)
		State.LANDING:
			_landing(delta)


func _stunned(delta: float) -> void:
	super._stunned(delta)
	if state != State.FLYING:
		return
	# Hurt in the air: start the trip again from wherever it ended up.
	_start = global_position
	_progress = 0.0
	_distance = maxf(global_position.distance_to(_target), 1.0)


func _on_hurt() -> void:
	if state == State.PERCHED:
		_flee()


# --- states ------------------------------------------------------------------------------------

func _perched(delta: float) -> void:
	if global_position.distance_to(perch) > KNOCKED_OFF:
		_take_off(Perches.pick_near(global_position, 40.0, _rng))
		return
	velocity = Vector3.ZERO
	global_position = perch
	_alarm_left -= delta
	var alarmed := _alarm_left <= 0.0 and _alarm_left > -1.0
	if alarmed or _should_flee():
		_flee()
		return
	_hop_left -= delta
	if _hop_left <= 0.0 and not has_animation("sleep") and not is_resting_hours():
		_hop_left = _rng.randf_range(HOP_EVERY.x, HOP_EVERY.y)
		_take_off(Perches.pick_near(global_position, 25.0, _rng))
		return
	_rest(delta)


## Sitting: owls sleep until the hero is near, birds look around now and then.
func _rest(delta: float) -> void:
	_state_left -= delta
	if has_animation("sleep") and _alerted <= 0.0 and is_resting_hours():
		play("sleep")
	elif _state_left > 0.0:
		return
	else:
		_state_left = _rng.randf_range(3.0, 7.0)
		play("look" if has_animation("look") and _rng.randf() < 0.4 else "idle")


func _flying(delta: float) -> void:
	_progress = minf(_progress + species.run_speed * health.speed_factor() * delta / _distance, 1.0)
	var spot := _start.lerp(_target, _progress)
	spot.y += sin(PI * _progress) * _arc
	var heading := _target - _start
	global_position = spot
	face(heading, delta * 2.0)
	if _progress >= 1.0:
		_land()


func _landing(delta: float) -> void:
	global_position = perch
	_state_left -= delta
	if _state_left <= 0.0:
		_enter(State.PERCHED)


# --- transitions -------------------------------------------------------------------------------

func _should_flee() -> bool:
	if _provoked > 0.0:
		return true
	var player := _get_player()
	if player == null or _alerted <= 0.0:
		return false
	return player_distance() < species.flee_distance * clampf(player.noise_level(), 0.5, 2.0)


## Takes off for a tree away from whatever scared it, and tells the flock to follow.
func _flee() -> void:
	var away := global_position - _threat
	away.y = 0.0
	if away.length() < 0.1:
		away = -_facing()
	var far := global_position + away.normalized() * _rng.randf_range(FLEE_REACH.x, FLEE_REACH.y)
	var target := Perches.pick_near(far, 35.0, _rng)
	if target == Vector3.INF:
		target = Perches.pick_near(global_position, 90.0, _rng)
	_take_off(target)
	for mate in flock:
		if is_instance_valid(mate) and mate != self:
			mate.alarm(_threat)


## Another bird of the flock took off: follow in a moment.
func alarm(from: Vector3) -> void:
	_threat = from
	_alarm_left = _rng.randf_range(0.05, 0.5)


func _take_off(target: Vector3) -> void:
	if target == Vector3.INF:
		return
	_alarm_left = -1.0
	_start = global_position
	_target = target
	_distance = maxf(_start.distance_to(_target), 1.0)
	_progress = 0.0
	_arc = clampf(_distance * 0.2, 2.0, 14.0)
	_enter(State.FLYING)


func _land() -> void:
	perch = _target
	home = perch
	_enter(State.LANDING)


func _enter(next: State) -> void:
	state = next
	match next:
		State.PERCHED:
			_state_left = 0.0
			_settle(_rng.randf() * TAU)
		State.FLYING:
			play("fly")
		State.LANDING:
			_state_left = LAND_TIME
			play("land")


## Sits down on the perch, turned a random way.
func _settle(yaw: float) -> void:
	_model.rotation.x = 0.0
	_model.rotation.y = yaw
	play("idle")
