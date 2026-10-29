class_name FlyingPredator
extends Animal
## A bird of prey. It circles high above its home, and when it spots the hero it dives, strikes
## once with a shove, climbs away and waits before trying again. Hurt it and it still comes,
## stun it and it falls out of the sky. The state machine:
## [codeblock]
## SOAR --(sees the hero, cooldown over)--> DIVE --(close enough)--> RETREAT --(timer)--> SOAR
## DIVE --(lost the hero or took too long)--> RETREAT
## [/codeblock]

enum State { SOAR, DIVE, RETREAT }

const RETREAT_TIME := 3.5
const DIVE_GIVE_UP := 5.0
const ORBIT_LEAD := 0.45  # radians ahead of itself that it aims along the circle
const ACCELERATION := 14.0

var state := State.SOAR

var _angle := 0.0
var _state_time := 0.0
var _cooldown := 3.0
var _orbit_clockwise := true


func _ready() -> void:
	super._ready()
	_orbit_clockwise = _rng.randf() < 0.5
	_angle = _rng.randf() * TAU
	global_position.y = _cruise_altitude(global_position)
	_enter(State.SOAR)


func _think(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	_state_time += delta
	match state:
		State.SOAR:
			_soar(delta)
		State.DIVE:
			_dive(delta)
		State.RETREAT:
			_retreat(delta)


func _stunned(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
	velocity.y -= GRAVITY * delta
	move_and_slide()
	_tilt(delta)


func _enter(next: State) -> void:
	state = next
	_state_time = 0.0
	match next:
		State.SOAR:
			var offset := global_position - home
			_angle = atan2(offset.z, offset.x)
			play("soar")
		State.DIVE:
			play("dive" if has_animation("dive") else "fly")
		State.RETREAT:
			play("flap")
			_cooldown = species.attack_cooldown


func _soar(delta: float) -> void:
	_angle += (-1.0 if _orbit_clockwise else 1.0) * delta * species.walk_speed / maxf(species.home_radius, 1.0)
	var lead := _angle + (-ORBIT_LEAD if _orbit_clockwise else ORBIT_LEAD)
	var spot := home + Vector3(cos(lead), 0.0, sin(lead)) * species.home_radius
	spot.y = _cruise_altitude(spot)
	_fly_toward(spot, species.walk_speed, delta)
	var hunting := species.temperament == Species.Temperament.AGGRESSIVE and not is_resting_hours()
	if _cooldown <= 0.0 and (sees_player or hears_player) and hunting:
		_enter(State.DIVE)


func _dive(delta: float) -> void:
	var player := _get_player()
	if player == null or _state_time > DIVE_GIVE_UP or not player.health.is_alive():
		_enter(State.RETREAT)
		return
	var target := player.global_position + Vector3.UP * 1.1
	_fly_toward(target, species.run_speed, delta)
	if global_position.distance_to(target) <= species.attack_range:
		_strike(player)
		_enter(State.RETREAT)


func _retreat(delta: float) -> void:
	var away := global_position - _threat
	away.y = 0.0
	var spot := global_position + away.normalized() * 30.0
	spot.y = _cruise_altitude(spot) + 10.0
	_fly_toward(spot, species.walk_speed * 1.5, delta)
	if _state_time > RETREAT_TIME:
		_enter(State.SOAR)


func _strike(player: Player) -> void:
	var player_health := Health.of(player)
	var away := player.global_position - global_position
	away.y = 0.0
	player_health.take_damage(species.attack_damage)
	player_health.push(away.normalized() * species.attack_push + Vector3.UP * 3.0)


# --- flight ------------------------------------------------------------------------------------

func _cruise_altitude(spot: Vector3) -> float:
	var terrain := get_terrain()
	var ground := terrain.height_at(spot.x, spot.z) if terrain != null else spot.y - species.cruise_height
	return ground + species.cruise_height


## Accelerates towards [param spot] and banks and pitches along the way.
func _fly_toward(spot: Vector3, speed: float, delta: float) -> void:
	var wanted := (spot - global_position).normalized() * speed * health.speed_factor()
	velocity = velocity.move_toward(wanted + _knock, ACCELERATION * delta)
	move_and_slide()
	face(Vector3(velocity.x, 0.0, velocity.z), delta)
	_tilt(delta)


## Noses down when diving and up when climbing.
func _tilt(delta: float) -> void:
	var speed := velocity.length()
	var pitch := asin(clampf(-velocity.y / maxf(speed, 0.1), -1.0, 1.0)) if speed > 1.0 else 0.0
	_model.rotation.x = lerp_angle(_model.rotation.x, pitch, 4.0 * delta)
