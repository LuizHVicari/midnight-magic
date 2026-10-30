class_name Foe
extends Animal
## A camp enemy (bandit, archer, brute): a KayKit character built from a [FoeSpecies]. It is an
## [Animal] underneath, so it has [Health], gets pushed, stunned, slowed and set on fire like
## anything else, and leaves a corpse to loot, but it behaves very differently:
##
## It never just sees you. Each sense feeds [member awareness], which rises faster the closer, the
## more exposed and the louder you are, and sinks back when you are gone. A little awareness makes
## it suspicious ("?"), full awareness makes it fight ("!"). Cover, crouching, the dark and a quiet
## walk all slow it down, and every kind notices differently (see [FoeSpecies]).
## [codeblock]
## REST/IDLE/PATROL --(awareness)--> SUSPICIOUS --> SEARCH --> RETURN --> IDLE
##        any calm state --(full awareness, or hurt)--> ENGAGE <--> ATTACK
## ENGAGE --(lost you, or too far from camp)--> SEARCH / RETURN
## [/codeblock]
## Set [member species], [member level], [member camp] and [member home] before adding it.

enum State { REST, STAND_UP, IDLE, PATROL, SUSPICIOUS, SEARCH, ENGAGE, ATTACK, RETURN }
enum Blow { MELEE, STAB, SHOT }

const ANIMATIONS := {
	"idle": "Rig_Medium_General/Idle_A",
	"look": "Rig_Medium_General/Idle_B",
	"hit": "Rig_Medium_General/Hit_A",
	"walk": "Rig_Medium_MovementBasic/Walking_A",
	"run": "Rig_Medium_MovementBasic/Running_A",
	"sit": "Rig_Medium_Simulation/Sit_Floor_Idle",
	"stand_up": "Rig_Medium_Simulation/Sit_Floor_StandUp",
	"block": "Rig_Medium_CombatMelee/Melee_Blocking",
	"aim": "Rig_Medium_CombatRanged/Ranged_Bow_Aiming_Idle",
}
const LOOPING := ["idle", "look", "walk", "run", "sit", "block", "aim"]
const LIBRARIES := {
	"Rig_Medium_General": "res://assets/animations/Rig_Medium_General.glb",
	"Rig_Medium_MovementBasic": "res://assets/animations/Rig_Medium_MovementBasic.glb",
	"Rig_Medium_Simulation": "res://assets/animations/Rig_Medium_Simulation.glb",
	"Rig_Medium_CombatMelee": "res://assets/animations/Rig_Medium_CombatMelee.glb",
	"Rig_Medium_CombatRanged": "res://assets/animations/Rig_Medium_CombatRanged.glb",
}
const MELEE_LIBRARY := "Rig_Medium_CombatMelee/"
const RANGED_LIBRARY := "Rig_Medium_CombatRanged/"
const DEATHS := ["Rig_Medium_General/Death_A", "Rig_Medium_General/Death_B"]

const SUSPECT := 0.35  # awareness at which it gets suspicious
const DECAY := 0.16  # awareness lost per second when it senses nothing
const NOTICE_SPEED := 0.5  # scales every awareness gain: lower is more forgiving to sneakers
const LOSE_TIME := 5.0  # seconds without sensing you before it stops chasing
const STAGGER_TIME := 0.4
const STAGGER_IMMUNE := 1.5
const LOOKAHEAD := 1.6
## Melee foes sprint in from afar so a hero cannot simply shoot them down while they walk up.
const CHARGE_BONUS := 0.3
const CHARGE_FROM := 8.0
const ALARM_NEAR := 18.0
const ALARM_FAR := 35.0
const FLANK_SWEEP := 0.5  # share of its distance to the hero it aims to the side by
const FLANK_WIDE := 7.0
const ALARM_DELAY := 0.04  # seconds of reaction per meter between the shouter and the one who hears
const HEALTH_PER_LEVEL := 0.22
const DAMAGE_PER_LEVEL := 0.12
const REWARD_PER_LEVEL := 0.2

var level := 1
var camp: FoeCamp
## Spawns sitting down by the fire instead of standing guard.
var resting := false
## What a resting foe looks at while it sits.
var look_at_point := Vector3.INF
var state := State.IDLE
var awareness := 0.0

var _foe: FoeSpecies
var _post := Vector3.ZERO  # where it spawned; a resting foe goes back to sit here
var _last_known := Vector3.ZERO
var _state_time := 0.0
var _state_left := 0.0
var _goal := Vector3.ZERO
var _stuck := 0.0
var _lost_for := 0.0
var _attack_cd := 0.0
var _blow := Blow.MELEE
var _blow_time := 0.0
var _blow_len := 1.0
var _blow_at := 0.5
var _struck := false
var _stagger := 0.0
var _stagger_immune := 0.0
var _alarmed := false
var _mark := AlertMark.new()


func _ready() -> void:
	_foe = species as FoeSpecies
	_post = global_position
	collision_mask |= Combat.STONE  # stone pillars are solid to foes too
	super._ready()
	_build_mark()
	if look_at_point != Vector3.INF:
		_model.rotation.y = atan2(look_at_point.x - global_position.x, look_at_point.z - global_position.z)
	_enter(State.REST if resting else State.IDLE)


func _join_groups() -> void:
	add_to_group("foes")


# --- body ----------------------------------------------------------------------------------------

func _build_model() -> void:
	var scene := species.models[variant] if variant >= 0 else species.random_model(_rng)
	_model = scene.instantiate()
	_model.name = "Model"
	_model.scale = Vector3.ONE * species.model_scale
	add_child(_model)
	_tint()
	_attach(_foe.weapon_right, "handslot.r")
	_attach(_foe.weapon_left, "handslot.l")
	_animation_player = AnimationPlayer.new()
	_animation_player.name = "Animations"
	add_child(_animation_player)
	_animation_player.root_node = NodePath("../Model")
	for library_name: String in LIBRARIES:
		_animation_player.add_animation_library(library_name, load(LIBRARIES[library_name]))
	for role: String in ANIMATIONS:
		_animations[role] = ANIMATIONS[role]
		if role in LOOPING:
			_animation_player.get_animation(ANIMATIONS[role]).loop_mode = Animation.LOOP_LINEAR


## Colors the cloth by multiplying the texture, on per-instance copies of the materials.
func _tint() -> void:
	if _foe.tint == Color.WHITE:
		return
	for mesh_node: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh_node.mesh.get_surface_count():
			var original := mesh_node.mesh.surface_get_material(surface) as BaseMaterial3D
			if original == null:
				continue
			var copy := original.duplicate() as BaseMaterial3D
			copy.albedo_color = _foe.tint
			mesh_node.set_surface_override_material(surface, copy)


func _attach(weapon: PackedScene, bone: String) -> void:
	if weapon == null:
		return
	var skeleton: Skeleton3D = _model.find_child("Skeleton3D", true, false)
	var slot := BoneAttachment3D.new()
	slot.bone_name = bone
	skeleton.add_child(slot)
	slot.add_child(weapon.instantiate())


func _build_health() -> void:
	super._build_health()
	health.maximum = species.max_health * (1.0 + HEALTH_PER_LEVEL * (level - 1))
	health.value = health.maximum
	health.changed.emit(health.value, health.maximum)
	if _foe.guard_taken < 1.0:
		health.damage_filter = _guard


## Heavies take only part of the damage that comes from the front, while on their feet.
func _guard(amount: float, _element: Element, from: Vector3) -> float:
	if state == State.ATTACK or state == State.REST:
		return amount
	var source := from
	if source == Vector3.INF:
		var player := _get_player()
		source = player.global_position if player != null else Vector3.INF
	if source == Vector3.INF:
		return amount
	var toward := source - global_position
	toward.y = 0.0
	return amount * _foe.guard_taken if _facing().angle_to(toward) < deg_to_rad(80.0) else amount


func _build_mark() -> void:
	_mark.position.y = species.body_height + 1.8
	add_child(_mark)


func _plate_title() -> String:
	return "%s  Lv %d" % [species.display_name, level]


func _update_plate() -> void:
	_plate.show_plate(not dead and (state == State.ENGAGE or state == State.ATTACK or _provoked > 0.0))


# --- senses --------------------------------------------------------------------------------------

## Notices the hero little by little. Gains per second come from sight (how much of the hero it
## can see, how close) and from hearing (how loud, how close); with neither, awareness drains.
func _sense() -> void:
	var player := _get_player()
	sees_player = false
	hears_player = false
	if player == null or not player.health.is_alive():
		awareness = maxf(awareness - DECAY * SENSE_EVERY, 0.0)
		_update_mark()
		return
	var to := player.global_position - global_position
	var gain := (_sight_gain(player, to) + _hearing_gain(player, to)) * NOTICE_SPEED
	if gain > 0.0:
		awareness = minf(awareness + gain * SENSE_EVERY, 1.0)
		_last_known = player.global_position
	else:
		awareness = maxf(awareness - DECAY * SENSE_EVERY, 0.0)
	if gain > 0.0 and (state == State.ENGAGE or state == State.ATTACK):
		awareness = 1.0
	_update_mark()


func _sight_gain(player: Player, to: Vector3) -> float:
	var sitting := state == State.REST
	var range_now := _foe.sight_range * lerpf(1.0, 0.65, _night_amount()) * player.visibility_factor()
	range_now *= 0.5 if sitting else 1.0
	var dist := to.length()
	if dist > range_now:
		return 0.0
	var flat := Vector3(to.x, 0.0, to.z)
	if dist > 1.5 and _facing().angle_to(flat) > deg_to_rad(_foe.sight_angle * 0.5):
		return 0.0
	var exposed := _exposed_share(player)
	if exposed <= 0.0:
		return 0.0
	sees_player = true
	var closeness := 1.0 - dist / range_now
	# Being low and still shrinks the range and also slows the noticing; running makes it faster.
	return _foe.alertness * exposed * (0.5 + 2.5 * pow(closeness, 1.2)) * (0.6 if sitting else 1.0) * player.visibility_factor()


func _hearing_gain(player: Player, to: Vector3) -> float:
	var radius := _foe.hearing_range * player.noise_level()
	var dist := to.length()
	if dist > radius * 1.4:
		return 0.0
	if not sees_player and not _line_clear(eye(), player.global_position + Vector3.UP * 1.2, player):
		radius *= 0.65  # walls and rocks muffle sound
	if dist > radius:
		return 0.0
	hears_player = true
	return _foe.alertness * (0.4 + 2.0 * (1.0 - dist / radius))


## How much of the hero is in view: 1 in the open, half behind low cover, 0 fully hidden.
func _exposed_share(player: Player) -> float:
	var points := player.cover_points()
	var seen := 0
	for point in points:
		seen += 1 if _line_clear(eye(), point, player) else 0
	return float(seen) / float(points.size())


## Whether nothing solid is between the two points. Animals and other foes do not hide anyone.
func _line_clear(from: Vector3, to: Vector3, player: Player) -> bool:
	var skipped: Array[RID] = [get_rid()]
	for attempt in 4:
		var query := PhysicsRayQueryParameters3D.create(from, to, Combat.WORLD | Combat.STONE)
		query.exclude = skipped
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or hit["collider"] == player:
			return true
		if hit["collider"] is Animal:
			skipped.append((hit["collider"] as Animal).get_rid())
			continue
		return false
	return false


func _night_amount() -> float:
	var clock := get_tree().get_first_node_in_group("day_night") as DayNight
	return clock.night if clock != null else 0.0


## The gauge over its head: fills as it gets suspicious, "!" when it fights.
func _update_mark() -> void:
	var fighting := state == State.ENGAGE or state == State.ATTACK
	if dead:
		_mark.visible = false
		return
	_mark.show_level(awareness, fighting, hears_player and not sees_player)


## A comrade raised the alarm: nearby ones come running, farther ones get suspicious. With a
## [param delay] the news takes that long to sink in.
func hear_alarm(at: Vector3, strength: float, delay := 0.0) -> void:
	if delay > 0.0:
		get_tree().create_timer(delay).timeout.connect(hear_alarm.bind(at, strength))
		return
	if dead or state == State.ENGAGE or state == State.ATTACK:
		return
	awareness = maxf(awareness, strength)
	_last_known = at


## Whether it is out fighting right now.
func is_fighting() -> bool:
	return not dead and (state == State.ENGAGE or state == State.ATTACK)


func is_melee() -> bool:
	return _foe.style != FoeSpecies.Style.ARCHER


func is_heavy() -> bool:
	return _foe.style == FoeSpecies.Style.HEAVY


# --- behavior ------------------------------------------------------------------------------------

func _think(delta: float) -> void:
	_state_time += delta
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_stagger = maxf(_stagger - delta, 0.0)
	_stagger_immune = maxf(_stagger_immune - delta, 0.0)
	_heal(delta)
	if _stagger > 0.0:
		_drive(Vector3.ZERO, 0.0, delta)
		return
	_notice()
	match state:
		State.REST:
			_drive(Vector3.ZERO, 0.0, delta)
		State.STAND_UP:
			_stand_up(delta)
		State.IDLE:
			_idle(delta)
		State.PATROL:
			_patrol(delta)
		State.SUSPICIOUS:
			_suspicious(delta)
		State.SEARCH:
			_search(delta)
		State.ENGAGE:
			_engage_tick(delta)
		State.ATTACK:
			_attack_tick(delta)
		State.RETURN:
			_return(delta)


## Moves between calm and alert as awareness changes.
func _notice() -> void:
	if state == State.ENGAGE or state == State.ATTACK or state == State.STAND_UP:
		return
	if awareness >= 1.0:
		_engage()
	elif awareness >= SUSPECT and state != State.SUSPICIOUS and state != State.SEARCH:
		_enter(State.STAND_UP if state == State.REST else State.SUSPICIOUS)


func _enter(next: State) -> void:
	state = next
	_state_time = 0.0
	_stuck = 0.0
	match next:
		State.REST:
			play("sit")
		State.STAND_UP:
			play("stand_up")
		State.IDLE:
			_state_left = _rng.randf_range(2.5, 6.0)
			play("idle")
		State.PATROL:
			_goal = _pick_goal()
		State.SUSPICIOUS:
			play("look")
		State.SEARCH:
			_goal = _last_known
		State.RETURN:
			_goal = _post if resting else _pick_goal()
		State.ENGAGE:
			_lost_for = 0.0


func _engage() -> void:
	_enter(State.ENGAGE)
	awareness = 1.0
	if not _alarmed and camp != null:
		_alarmed = true
		camp.raise_alarm(self, _last_known)
	_update_plate()
	_update_mark()


func _stand_up(delta: float) -> void:
	_drive(Vector3.ZERO, 0.0, delta)
	if _state_time < 1.1:
		return
	_enter(State.ENGAGE if awareness >= 1.0 else State.SUSPICIOUS)
	if state == State.ENGAGE:
		_engage()


func _idle(delta: float) -> void:
	_drive(Vector3.ZERO, 0.0, delta)
	_state_left -= delta
	if _state_left > 0.0:
		return
	if _rng.randf() < 0.6:
		_enter(State.PATROL)
	else:
		_enter(State.IDLE)
		play("look" if _rng.randf() < 0.5 else "idle")


func _patrol(delta: float) -> void:
	var to_goal := _goal - global_position
	to_goal.y = 0.0
	var speed := _walk_to(_goal, species.walk_speed, delta)
	play("walk")
	_stuck = _stuck + delta if speed < species.walk_speed * 0.25 else 0.0
	if to_goal.length() < 1.2 or _state_time > 9.0 or _stuck > 1.0:
		_enter(State.IDLE)


## Stops and turns towards what it noticed. If it stays uneasy it goes to look.
func _suspicious(delta: float) -> void:
	_drive(Vector3.ZERO, 0.0, delta)
	face(_last_known - global_position, delta)
	if _state_time > 1.6 and awareness >= 0.2:
		_enter(State.SEARCH)
	elif _state_time > 1.5 and awareness < 0.15:
		_enter(State.IDLE)


## Walks to where it last noticed the hero, looks around, then gives up and goes back.
func _search(delta: float) -> void:
	var to_goal := _goal - global_position
	to_goal.y = 0.0
	if to_goal.length() > 1.8 and _state_time < 10.0 and _stuck < 1.0:
		var speed := _walk_to(_goal, species.walk_speed * 1.15, delta)
		play("walk")
		_stuck = _stuck + delta if speed < species.walk_speed * 0.25 else 0.0
		return
	_drive(Vector3.ZERO, 0.0, delta)
	play("look")
	if _state_time > 14.0 or (to_goal.length() <= 1.8 and _state_time > 4.0):
		awareness = minf(awareness, 0.2)
		_enter(State.RETURN)


func _return(delta: float) -> void:
	var to_goal := _goal - global_position
	to_goal.y = 0.0
	var speed := _walk_to(_goal, species.walk_speed * 1.25, delta)
	play("walk")
	_stuck = _stuck + delta if speed < species.walk_speed * 0.25 else 0.0
	if to_goal.length() < 1.2 or _state_time > 40.0 or _stuck > 3.0:
		_alarmed = false
		_enter(State.REST if resting else State.IDLE)


## Out of sight for a while, or too far from camp: stop chasing.
func _engage_tick(delta: float) -> void:
	var player := _get_player()
	if player == null or not player.health.is_alive():
		_alarmed = false
		_enter(State.RETURN)
		return
	_lost_for = 0.0 if (sees_player or hears_player) else _lost_for + delta
	if global_position.distance_to(home) > _foe.leash:
		_give_up(State.RETURN)
		return
	if _lost_for > LOSE_TIME:
		_give_up(State.SEARCH)
		return
	if _foe.style == FoeSpecies.Style.ARCHER:
		_archer(player, delta)
	else:
		_brawler(player, delta)


func _give_up(next: State) -> void:
	_alarmed = false
	awareness = minf(awareness, 0.5)
	_enter(next)


## Melee and heavy foes close the distance and swing when in reach.
func _brawler(player: Player, delta: float) -> void:
	var to := player.global_position - global_position
	to.y = 0.0
	if to.length() > _foe.reach * 0.85:
		var charge := 1.0 + (CHARGE_BONUS if to.length() > CHARGE_FROM else 0.0)
		_walk_to(_flank_point(player), species.run_speed * charge, delta, to.length() > 3.5)
		play("run")
		return
	_drive(Vector3.ZERO, 0.0, delta)
	face(to, delta)
	if _attack_cd > 0.0:
		play("block" if _foe.guard_taken < 1.0 else "idle")
		return
	if _facing().angle_to(to) < deg_to_rad(35.0):
		_begin_blow(Blow.MELEE)


## The spot beside the hero this foe heads for, so a group fans out and comes from several
## sides instead of lining up behind one another.
func _flank_point(player: Player) -> Vector3:
	var away := Vector3.ZERO
	if camp != null:
		away = camp.global_position - player.global_position
	away.y = 0.0
	if away.length() < 0.1:
		return player.global_position
	var bearing := away.normalized().rotated(Vector3.UP, camp.flank_angle(self))
	# Far off it aims wide of the hero and closes in as it gets near, so the group sweeps round.
	var gap := global_position.distance_to(player.global_position)
	var radius := clampf(gap * FLANK_SWEEP, _foe.reach * 0.75, FLANK_WIDE)
	return player.global_position + bearing * radius


## Archers hold a distance: back off when you get close, stab if cornered, shoot when in range.
func _archer(player: Player, delta: float) -> void:
	var to := player.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	if dist < _foe.reach and _attack_cd <= 0.0:
		_begin_blow(Blow.STAB)
		return
	if dist < _foe.preferred_range.x:
		_drive(_steer(-to.normalized()), species.run_speed * 0.9, delta, to)
		play("run")
		return
	if dist > _foe.preferred_range.y or not sees_player:
		_walk_to(player.global_position, species.run_speed * 0.8, delta, true)
		play("run")
		return
	_drive(Vector3.ZERO, 0.0, delta)
	face(to, delta)
	if _attack_cd > 0.0:
		play("aim")
		return
	_begin_blow(Blow.SHOT)


func _begin_blow(kind: Blow) -> void:
	state = State.ATTACK
	_blow = kind
	_blow_time = 0.0
	_struck = false
	var animation := ""
	var speed := 1.0
	match kind:
		Blow.MELEE:
			animation = MELEE_LIBRARY + _foe.attack_animation
			speed = _foe.attack_speed
			_blow_at = _foe.windup / speed
		Blow.STAB:
			animation = MELEE_LIBRARY + "Melee_1H_Attack_Stab"
			speed = 1.4
			_blow_at = 0.55 / speed
		Blow.SHOT:
			animation = RANGED_LIBRARY + "Ranged_Bow_Draw"
			speed = 1.0
			_blow_at = 1.15
	_blow_len = _blow_at + (0.5 if kind == Blow.SHOT else _animation_player.get_animation(animation).length / speed - _blow_at)
	_animation_player.play(animation, 0.1, speed)


func _attack_tick(delta: float) -> void:
	_blow_time += delta
	var player := _get_player()
	_drive(Vector3.ZERO, 0.0, delta)
	if player != null and _blow_time < _blow_at * 0.8:
		var to := player.global_position - global_position
		to.y = 0.0
		face(to, delta * 0.7)
	if not _struck and _blow_time >= _blow_at:
		_struck = true
		_land_blow(player)
	if _blow_time >= _blow_len:
		_attack_cd = species.attack_cooldown * (1.0 if _blow != Blow.STAB else 0.7)
		_enter(State.ENGAGE)


func _land_blow(player: Player) -> void:
	if player == null or not player.health.is_alive():
		return
	if _blow == Blow.SHOT:
		_shoot(player)
		_animation_player.play(RANGED_LIBRARY + "Ranged_Bow_Release", 0.05, 1.3)
		return
	var to := player.global_position - global_position
	to.y = 0.0
	var reach := _foe.reach * 1.4
	if to.length() > reach or _facing().angle_to(to) > deg_to_rad(75.0):
		return  # it swung at where you were
	var power := damage_multiplier()
	var amount := (_foe.damage if _blow == Blow.MELEE else _foe.stab_damage) * power
	player.health.take_damage(amount, null, global_position)
	player.health.push(to.normalized() * species.attack_push + Vector3.UP * 1.5)
	Vfx.sparks(get_parent(), player.global_position + Vector3.UP * 1.3, Color(1.0, 0.55, 0.4), 8)


func _shoot(player: Player) -> void:
	var arrow := Arrow.new()
	var from := global_position + Vector3.UP * 1.7 + _facing() * 0.6
	var target := player.global_position + Vector3.UP * 1.2 + Vector3(_rng.randf_range(-0.35, 0.35), _rng.randf_range(-0.2, 0.3), _rng.randf_range(-0.35, 0.35))
	var flight := from.distance_to(target) / _foe.arrow_speed
	# Aims a touch above the target to make up for the drop, but not ahead of a moving hero.
	arrow.velocity = (target - from) / flight + Vector3.UP * 0.5 * 7.0 * flight
	arrow.damage = _foe.damage * damage_multiplier()
	arrow.shooter = get_rid()
	arrow.position = from
	get_parent().add_child(arrow)


func damage_multiplier() -> float:
	return 1.0 + DAMAGE_PER_LEVEL * (level - 1)


func _on_hurt() -> void:
	if dead:
		return
	awareness = 1.0
	if state != State.ENGAGE and state != State.ATTACK:
		_engage()
	var interruptible := not _foe.poise and _stagger_immune <= 0.0
	var before_the_blow := state == State.ATTACK and _blow_time < _blow_at
	if interruptible and (state != State.ATTACK or before_the_blow):
		_stagger = STAGGER_TIME
		_stagger_immune = STAGGER_IMMUNE
		_animation_player.play("Rig_Medium_General/Hit_A", 0.05)
		if state == State.ATTACK:
			_attack_cd = 0.8
			_enter(State.ENGAGE)


## Slowly recovers when it is not fighting.
func _heal(delta: float) -> void:
	if state == State.ENGAGE or state == State.ATTACK or health.value >= health.maximum:
		return
	health.heal(health.maximum * 0.03 * delta)


# --- movement ------------------------------------------------------------------------------------

## Walks towards [param target] avoiding water, cliffs and obstacles; returns the speed it reached.
func _walk_to(target: Vector3, speed: float, delta: float, avoid := true) -> float:
	var direction := target - global_position
	direction.y = 0.0
	direction = direction.normalized()
	if avoid and _stuck < 0.6:
		direction = _steer(direction)
	_drive(direction, speed, delta)
	return Vector2(get_real_velocity().x, get_real_velocity().z).length()


## Moves along [param direction] on the flat, facing [param look] (or where it goes).
func _drive(direction: Vector3, speed: float, delta: float, look := Vector3.ZERO) -> void:
	var wanted := direction * speed * health.speed_factor()
	velocity.x = move_toward(velocity.x, wanted.x, 40.0 * delta) + _knock.x * delta * 8.0
	velocity.z = move_toward(velocity.z, wanted.z, 40.0 * delta) + _knock.z * delta * 8.0
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	if look != Vector3.ZERO:
		face(look, delta)
	elif direction != Vector3.ZERO:
		face(direction, delta)
	move_and_slide()


func _steer(direction: Vector3) -> Vector3:
	for turn in [0.0, 0.6, -0.6, 1.2, -1.2, 1.9, -1.9]:
		var candidate := direction.rotated(Vector3.UP, turn)
		if _passable(candidate):
			return candidate
	return Vector3.ZERO


func _passable(direction: Vector3) -> bool:
	var terrain := get_terrain()
	if terrain != null:
		var ahead := global_position + direction * LOOKAHEAD
		var dry := not terrain.is_water(ahead.x, ahead.z) and terrain.normal_at(ahead.x, ahead.z).y > 0.7
		if not dry or not terrain.in_bounds(ahead.x, ahead.z, 8.0):
			return false
	return not test_move(global_transform.translated(Vector3.UP * 0.5), direction * 1.4)


func _pick_goal() -> Vector3:
	for attempt in 6:
		var flat := Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(2.0, _foe.patrol_radius)
		var spot := home + Vector3(flat.x, 0.0, flat.y)
		var terrain := get_terrain()
		if terrain == null or (not terrain.is_water(spot.x, spot.z) and terrain.normal_at(spot.x, spot.z).y > 0.8):
			return spot
	return home


# --- death ---------------------------------------------------------------------------------------

func _play_death() -> void:
	_mark.visible = false
	_animation_player.play(DEATHS[_rng.randi() % DEATHS.size()], 0.1)
	var player := _get_player()
	if player != null:
		player.gain_xp(roundi(_foe.xp * (1.0 + REWARD_PER_LEVEL * (level - 1))))


func _roll_loot() -> void:
	var coins := _rng.randi_range(_foe.coins.x, _foe.coins.y)
	_loot.append({"item": "Coins", "count": maxi(1, roundi(coins * (1.0 + REWARD_PER_LEVEL * (level - 1))))})
	super._roll_loot()
