class_name Animal
extends CharacterBody3D
## Base of every wild animal. It builds the body from a [Species] (model, collider, [Health]),
## senses the hero (sight cone and hearing), reacts to hits and spells (stun, slow, shove), and
## drops loot when it dies. What it actually does with all that is up to the family that extends
## it: [GroundAnimal] wanders and flees, [FlyingPredator] circles and dives. Set [member species]
## and the position before adding it to the tree.

const ALERT_TIME := 4.0
const PROVOKED_TIME := 8.0
const SENSE_EVERY := 0.2
const LOD_RADIUS := 170.0  # farther than this from the hero an animal is frozen and hidden
const LOD_EVERY := 0.7
const GRAVITY := 24.0
const LIFT_ACCEL := 60.0
## How long a lift or a pull keeps hold after the last time it was applied.
const CARRY_HOLD := 0.15
const CORPSE_TIME := 90.0  # a corpse waits this long to be looted
const LOOT_PROMPT_RANGE := 6.0
## Animations that play once; everything else loops.
const ONE_SHOT_ROLES := ["attack", "land", "leap", "eat_start", "eat_end"]
## A species without an animation for a role uses this one instead (walking is a slow run...).
const FALLBACKS := {"air": "run", "walk": "run", "look": "idle", "eat": "idle", "swim": "walk", "swim_idle": "idle", "swim_flee": "run"}

static var _fur: StandardMaterial3D

var species: Species
## Which of the species' models to use; -1 picks one at random. A flock shares one.
var variant := -1
var health := Health.new()
## What the animal stays near. Defaults to where it was placed.
var home := Vector3.ZERO

var sees_player := false
var hears_player := false
var dead := false
var looted := false

var _rng := RandomNumberGenerator.new()
var _model: Node3D
var _animation_player: AnimationPlayer
var _animations := {}  # role -> full animation name
var _player: Player
var _terrain: Terrain
var _sense_wait := 0.0
var _alerted := 0.0  # seconds left of being on alert after noticing the hero
var _provoked := 0.0  # seconds left of being afraid or angry after being hurt
var _threat := Vector3.ZERO  # where the hero was last seen or heard
var _knock := Vector3.ZERO
var _lift_speed := 0.0
var _lift_left := 0.0
var _pull := Vector3.ZERO
var _pull_left := 0.0
var _air_speed := 0.0  # how fast it was falling a moment ago
var _plate := Nameplate.new()
var _loot: Array[Dictionary] = []  # {"item": String, "count": int}
var _corpse: Tween
var _prompt: Label3D


func _ready() -> void:
	_rng.randomize()
	if home == Vector3.ZERO:
		home = position
	_build_model()
	_build_body()
	_build_health()
	_build_plate()
	_join_groups()
	var lod := Timer.new()
	lod.wait_time = LOD_EVERY
	lod.autostart = true
	lod.timeout.connect(_update_lod)
	add_child(lod)


## Wild animals are tracked by the [WildlifeManager] through this group; other creatures that
## extend Animal (the camp foes) use their own so the manager never counts or removes them.
func _join_groups() -> void:
	add_to_group("animals")


## Vertex-painted fur shared by every animal: the models carry their colors in the vertices.
static func fur_material() -> StandardMaterial3D:
	if _fur == null:
		_fur = StandardMaterial3D.new()
		_fur.vertex_color_use_as_albedo = true
		_fur.vertex_color_is_srgb = true
		_fur.roughness = 1.0
	return _fur


func _physics_process(delta: float) -> void:
	if dead:
		return
	_sense_wait -= delta
	if _sense_wait <= 0.0:
		_sense_wait = SENSE_EVERY
		_sense()
		_update_plate()
	_alerted = maxf(_alerted - delta, 0.0)
	_provoked = maxf(_provoked - delta, 0.0)
	_knock = _knock.move_toward(Vector3.ZERO, 25.0 * delta)
	_track_landing()
	if _carried(delta):
		return
	if health.is_stunned():
		_stunned(delta)
		return
	_think(delta)


## Only creatures that walk can be lifted, pulled or hurt by a fall; fliers and perched birds have
## their own ways of staying up.
func _grounded_kind() -> bool:
	return species.behavior == Species.Behavior.GROUND


## Carries it upwards at [param speed] (m/s) while this keeps being called. It cannot act.
func lift(speed: float) -> void:
	if dead or not _grounded_kind():
		return
	_lift_speed = speed
	_lift_left = CARRY_HOLD


## Drags it along at [param wanted] (m/s, sideways) while this keeps being called. It cannot act.
func pull(wanted: Vector3) -> void:
	if dead or not _grounded_kind():
		return
	_pull = wanted
	_pull_left = CARRY_HOLD


## Whether something is lifting or pulling it; if so it is moved here instead of thinking.
func _carried(delta: float) -> bool:
	_lift_left = maxf(_lift_left - delta, 0.0)
	_pull_left = maxf(_pull_left - delta, 0.0)
	if _lift_left <= 0.0 and _pull_left <= 0.0:
		return false
	var flat := _pull if _pull_left > 0.0 else Vector3.ZERO
	velocity.x = flat.x + _knock.x
	velocity.z = flat.z + _knock.z
	if _lift_left > 0.0:
		velocity.y = move_toward(velocity.y, _lift_speed, LIFT_ACCEL * delta)
	else:
		velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	play("air" if not is_on_floor() else "run")
	return true


## Remembers how fast it is falling, and when it touches down lets [Health] work out the hurt.
func _track_landing() -> void:
	if not _grounded_kind():
		return
	if not is_on_floor():
		_air_speed = maxf(-velocity.y, 0.0)
		return
	if _air_speed <= 0.0:
		return
	var damage := health.land(_air_speed)
	_air_speed = 0.0
	if damage > 0.0:
		_landed(damage)


## Hook for subclasses: it landed hard enough to be hurt.
func _landed(_damage: float) -> void:
	pass


## One tick of behavior. Subclasses move the animal here.
func _think(_delta: float) -> void:
	pass


## Stunned animals cannot act. Ground animals just stand there; fliers fall.
func _stunned(delta: float) -> void:
	velocity.x = _knock.x
	velocity.z = _knock.z
	velocity.y -= GRAVITY * delta
	move_and_slide()
	play("idle")


## Called when something hurts the animal. Subclasses can add their own reaction.
func _on_hurt() -> void:
	pass


# --- model -------------------------------------------------------------------------------------

func _build_model() -> void:
	var scene := species.models[variant] if variant >= 0 else species.random_model(_rng)
	_model = scene.instantiate()
	_model.scale = Vector3.ONE * species.model_scale
	add_child(_model)
	for mesh: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = fur_material()
	var players := _model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	_animation_player = players[0]
	_map_animations()


## Finds each role's real animation by the end of its name and makes the repeating ones loop.
func _map_animations() -> void:
	for role: String in species.animations:
		var wanted: String = species.animations[role]
		for full_name in _animation_player.get_animation_list():
			if String(full_name).get_slice("|", String(full_name).count("|")) == wanted:
				_animations[role] = full_name
		if not _animations.has(role):
			continue
		var animation := _animation_player.get_animation(_animations[role])
		animation.loop_mode = Animation.LOOP_NONE if role in ONE_SHOT_ROLES else Animation.LOOP_LINEAR


## Plays the animation for [param role] (idle, walk, run...) if the species has one.
func play(role: String, speed := 1.0) -> void:
	var used := role
	while not _animations.has(used) and FALLBACKS.has(used):
		used = FALLBACKS[used]
	if not _animations.has(used):
		return
	if used != role and role == "walk":
		speed *= 0.55  # no walk cycle: a slowed run reads as one
	var full: String = _animations[used]
	if _animation_player.current_animation == full:
		_animation_player.speed_scale = speed
		return
	_animation_player.play(full, 0.2, speed)


func has_animation(role: String) -> bool:
	return _animations.has(role)


## Turns the model to look along [param direction] on the flat.
func face(direction: Vector3, delta: float) -> void:
	if Vector2(direction.x, direction.z).length() < 0.01:
		return
	var target := atan2(direction.x, direction.z)  # the models look along +Z
	_model.rotation.y = lerp_angle(_model.rotation.y, target, species.turn_speed * delta)


func _facing() -> Vector3:
	return Vector3(sin(_model.rotation.y), 0.0, cos(_model.rotation.y))


# --- body --------------------------------------------------------------------------------------

func _build_body() -> void:
	var capsule := CapsuleShape3D.new()
	capsule.radius = species.body_radius
	capsule.height = maxf(species.body_height, species.body_radius * 2.0)
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = capsule.height * 0.5
	add_child(shape)
	floor_snap_length = 0.5


func _build_health() -> void:
	health.name = "Health"
	health.maximum = species.max_health
	health.focus_height = species.body_height * 0.6
	add_child(health)
	health.damaged.connect(_on_damaged)
	health.pushed.connect(func(shove: Vector3) -> void: _knock = shove)
	health.died.connect(_die)


func _build_plate() -> void:
	_plate.position.y = species.body_height + 0.8
	var hostile := species.temperament == Species.Temperament.AGGRESSIVE
	_plate.setup(_plate_title(), Color(1.0, 0.5, 0.45) if hostile else Color(0.96, 0.94, 0.84))
	add_child(_plate)
	health.changed.connect(func(value: float, maximum: float) -> void: _plate.set_ratio(value / maximum))


## The text over the health bar.
func _plate_title() -> String:
	return species.display_name


## The health bar shows while the animal is fighting: hurt, or a hunter that has noticed the hero.
func _update_plate() -> void:
	var hunting := species.temperament == Species.Temperament.AGGRESSIVE and _alerted > 0.0
	_plate.show_plate(not dead and (_provoked > 0.0 or hunting))


func _on_damaged(amount: float, element: Element) -> void:
	_provoked = PROVOKED_TIME
	var player := _get_player()
	_threat = player.global_position if player != null else global_position
	_update_plate()
	var color := element.color if element != null else Color.WHITE
	DamagePopup.spawn(get_parent(), global_position + Vector3.UP * (species.body_height + 0.6), str(roundi(amount)), color)
	_on_hurt()


# --- senses ------------------------------------------------------------------------------------

func _get_player() -> Player:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Player
	return _player


func get_terrain() -> Terrain:
	if _terrain == null:
		_terrain = get_tree().get_first_node_in_group("terrain") as Terrain
	return _terrain


## Whether it is night right now; false when the scene has no day and night clock.
func is_night() -> bool:
	var clock := get_tree().get_first_node_in_group("day_night") as DayNight
	return clock != null and clock.night > 0.5


## Whether this is the hours the species sleeps or lies low: nights for day animals, days for
## night animals (owls).
func is_resting_hours() -> bool:
	match species.activity:
		Species.Activity.DAY:
			return is_night()
		Species.Activity.NIGHT:
			return not is_night()
	return false


func eye() -> Vector3:
	return global_position + Vector3.UP * species.body_height * 0.8


## Updates [member sees_player] and [member hears_player]; run a few times a second, not every frame.
func _sense() -> void:
	var player := _get_player()
	sees_player = false
	hears_player = false
	if player == null or not player.health.is_alive():
		return
	var to_player := player.global_position - global_position
	sees_player = _can_see(player, to_player)
	hears_player = to_player.length() < species.hearing_range * player.noise_level()
	if sees_player or hears_player:
		_alerted = ALERT_TIME
		_threat = player.global_position


func _can_see(player: Player, to_player: Vector3) -> bool:
	if to_player.length() > species.sight_range * player.visibility_factor():
		return false
	var flat := Vector3(to_player.x, 0.0, to_player.z)
	if flat.length() > 0.5 and _facing().angle_to(flat) > deg_to_rad(species.sight_angle * 0.5):
		return false
	var line := Combat.raycast(self, eye(), player.global_position + Vector3.UP * 1.2, [get_rid()])
	return line.is_empty() or line["collider"] == player


## Horizontal distance to the hero, or a huge number when there is none.
func player_distance() -> float:
	var player := _get_player()
	if player == null:
		return 1.0e9
	return Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length()


# --- freezing far from the hero ------------------------------------------------------------------

func _update_lod() -> void:
	var near := player_distance() < LOD_RADIUS
	set_physics_process(near and not dead)
	_model.visible = near


# --- death and loot ----------------------------------------------------------------------------

func _die() -> void:
	dead = true
	collision_layer = 0
	collision_mask = 0
	_plate.queue_free()
	var ground := Combat.raycast(self, global_position, global_position + Vector3.DOWN * 80.0, [get_rid()])
	var landing: float = global_position.y if ground.is_empty() else float(ground["position"].y)
	var terrain := get_terrain()
	if species.swims and terrain != null and terrain.is_water(global_position.x, global_position.z):
		landing = maxf(landing, terrain.water_level_at(global_position.x, global_position.z) - species.float_depth)
	_roll_loot()
	_corpse = create_tween()
	_corpse.tween_property(self, "global_position:y", landing, 0.5).set_ease(Tween.EASE_IN)
	_corpse.tween_callback(_offer_loot)
	_corpse.tween_interval(CORPSE_TIME)
	_corpse.tween_callback(_fade_away)
	_play_death()


## How the body goes down: animals topple over and freeze.
func _play_death() -> void:
	create_tween().tween_property(_model, "rotation:z", deg_to_rad(80.0), 0.35).set_trans(Tween.TRANS_BOUNCE)
	if _animation_player != null:
		_animation_player.pause()


func _roll_loot() -> void:
	for entry in species.loot:
		var count := entry.roll(_rng)
		if count > 0:
			_loot.append({"item": entry.item, "count": count})


## Once the corpse is on the ground it can be looted: a prompt shows when the hero is near.
func _offer_loot() -> void:
	if _loot.is_empty():
		return
	add_to_group("lootable")
	_prompt = Label3D.new()
	_prompt.text = "[E] Loot %s" % species.display_name
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.font_size = 44
	_prompt.pixel_size = 0.006
	_prompt.outline_size = 12
	_prompt.outline_modulate = Color(0.1, 0.06, 0.15)
	_prompt.modulate = Player.LOOT_COLOR
	_prompt.position.y = species.body_height + 0.6
	_prompt.visibility_range_end = LOOT_PROMPT_RANGE
	_prompt.visibility_range_end_margin = 1.5
	_prompt.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(_prompt)


## The hero loots the corpse: every item goes to their inventory, one after the other, and the
## body fades away.
func interact(player: Player) -> void:
	if looted:
		return
	looted = true
	remove_from_group("lootable")
	_prompt.queue_free()
	_corpse.kill()
	for entry in _loot:
		player.collect(entry["item"], entry["count"])
		await get_tree().create_timer(0.35).timeout
	_fade_away()


func _fade_away() -> void:
	var tween := create_tween()
	tween.tween_property(_model, "scale", Vector3.ZERO, 0.6)
	tween.tween_callback(queue_free)
