class_name Player
extends CharacterBody3D

@export var speed: float = 4.5
@export var sprint_multiplier: float = 1.7
@export var crouch_multiplier: float = 0.45
@export var block_multiplier: float = 0.5
@export var crouch_height: float = 1.7
@export var crouch_camera_drop: float = 0.5
@export var max_stamina: float = 100.0
@export var sprint_drain: float = 12.0  # per second while sprinting
@export var walk_regen: float = 6.0  # per second while moving without sprinting
@export var idle_regen: float = 20.0  # per second while standing still
@export var regen_delay: float = 0.7  # pause after sprinting before stamina comes back
@export var exhausted_recover: float = 0.3  # fraction needed to sprint again after running dry
@export var max_health: float = 100.0
@export var health_regen: float = 1.5  # per second, once out of danger
@export var regen_after: float = 6.0
@export var max_mana: float = 100.0
@export var mana_regen: float = 8.0  # per second
@export var mana_regen_delay: float = 1.0  # pause after casting before mana comes back
@export var primary: Element = preload("res://scenes/combat/elements/light.tres")
@export var secondary: Element = preload("res://scenes/combat/elements/wind.tres")
@export var jump_velocity: float = 9.0
@export var gravity_scale: float = 2.2
@export var fall_multiplier: float = 1.3
@export var mouse_sensitivity: float = 0.003
@export var turn_speed: float = 10.0
@export var max_step_height: float = 1.0
@export var shoulder_offset: float = 1.4  # camera slides right, so the hero sits left of the crosshair
@export var zoom_min: float = 1.5
@export var zoom_max: float = 10.0
@export var zoom_step: float = 0.5
@export var zoom_smoothing: float = 10.0

const ANIM_IDLE := "Rig_Medium_General/Idle_A"
const ANIM_WALK := "Rig_Medium_MovementBasic/Walking_A"
const ANIM_RUN := "Rig_Medium_MovementBasic/Running_A"
const ANIM_CROUCH := "Rig_Medium_MovementAdvanced/Crouching"
const ANIM_SNEAK := "Rig_Medium_MovementAdvanced/Sneaking"
const ANIM_BLOCK := "Rig_Medium_CombatMelee/Melee_Blocking"
const ANIM_CHANNEL := "Rig_Medium_CombatRanged/Ranged_Magic_Raise"
## Second into the raise where the wand is up and steady; a held cast freezes there.
const CHANNEL_HOLD := 1.1
const ANIM_THROW := "Rig_Medium_General/Throw"
const LOOPED_ANIMS := [ANIM_WALK, ANIM_CROUCH, ANIM_SNEAK, ANIM_BLOCK]
const ANIM_AIR := "Rig_Medium_MovementBasic/Jump_Idle"

signal stamina_changed(value: float, maximum: float, exhausted: bool)
signal mana_changed(value: float, maximum: float)
signal item_collected(item: String, count: int)

const WAND_SCENE := preload("res://assets/models/kaykit/wand.gltf")
const HAND_BONE := "handslot.r"

const STEP_PROBE_DISTANCE := 0.5
const LOOT_COLOR := Color(1.0, 0.82, 0.35)
## How close the hero has to be to a corpse to loot it.
const INTERACT_RANGE := 3.0
const SHIELD_DISTANCE := 1.6
const SHIELD_HEIGHT := 1.2
## Two forward taps within this many seconds start a sprint that lasts until forward is released.
const DOUBLE_TAP_WINDOW := 0.3

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var model: Node3D = $Model
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var body_shape: CollisionShape3D = $CollisionShape3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D

var attacking := false
var blocking := false:
	set(value):
		if value == blocking:
			return
		blocking = value
		if _shield:
			_shield.raise() if blocking else _shield.lower()
var crouching := false
var sprinting := false
var stamina := 0.0
var exhausted := false
var mana := 0.0
var health := Health.new()
## Where the hero returns after dying; the world sets it.
var respawn_point := Vector3.ZERO
var inventory := {}  # item name -> count
var _since_hurt := 0.0
var _regen_timer := 0.0
var _mana_timer := 0.0
var _cast_anim := ""
var _cast_lock := 0.0  # seconds the cast still roots the hero; 0 = until its animation ends
var _hold_at := 0.0  # animation position where the cast pose freezes; 0 = never
var _hand: Node3D
var _primary_attack: SpellAttack
var _secondary_attack: SpellAttack
var _last_forward_tap := -1000.0
var _double_tap_sprint := false
var target_zoom: float
var _shield := MagicShield.new()
var _stand_height: float
var _stand_center_y: float
var _pivot_rest_y: float


func _ready() -> void:
	collision_mask |= Combat.STONE  # stone cover is solid to the hero
	add_to_group("player")
	_build_health()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	target_zoom = spring_arm.spring_length
	spring_arm.position.x = shoulder_offset
	_stand_height = (body_shape.shape as CapsuleShape3D).height
	_stand_center_y = body_shape.position.y
	_pivot_rest_y = camera_pivot.position.y
	stamina = max_stamina
	stamina_changed.connect($Hud.add_bar(StatBar.Kind.STAMINA, true).set_value)
	stamina_changed.emit(stamina, max_stamina, exhausted)
	mana = max_mana
	mana_changed.connect($Hud.add_bar(StatBar.Kind.MANA).set_value)
	mana_changed.emit(mana, max_mana)
	_primary_attack = _equip_spell(primary)
	_secondary_attack = _equip_spell(secondary)
	for anim_name in LOOPED_ANIMS:
		anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	floor_snap_length = 0.4  # stick to the ground when walking down banks and steps
	anim.animation_finished.connect(_on_animation_finished)
	_equip_wand()
	add_child(_shield)


func _build_health() -> void:
	health.name = "Health"
	health.maximum = max_health
	health.targetable = false  # spells never lock on to the hero
	add_child(health)
	health.changed.connect($Hud.add_bar(StatBar.Kind.HEALTH).set_value)
	health.changed.emit(health.value, health.maximum)
	health.damaged.connect(func(_amount: float, _element: Element) -> void: _since_hurt = 0.0)
	health.pushed.connect(func(shove: Vector3) -> void: velocity += shove)
	health.died.connect(_on_died)


func _on_died() -> void:
	await get_tree().create_timer(1.5).timeout
	global_position = respawn_point
	velocity = Vector3.ZERO
	health.restore()
	mana = max_mana
	stamina = max_stamina
	mana_changed.emit(mana, max_mana)
	stamina_changed.emit(stamina, max_stamina, exhausted)


## Picks something up: it goes into [member inventory] and a gold "+1 Item" floats up.
func collect(item: String, count: int) -> void:
	inventory[item] = int(inventory.get(item, 0)) + count
	item_collected.emit(item, count)
	DamagePopup.spawn(get_parent(), global_position + Vector3.UP * 2.8, "+%d %s" % [count, item], LOOT_COLOR)


## How loud the hero is right now, for animals to hear: sneaking is quiet, sprinting and casting loud.
func noise_level() -> float:
	var moving := Vector2(velocity.x, velocity.z).length() > 0.5
	var level := 0.15
	if moving:
		level = 2.0 if sprinting else (0.35 if crouching else 1.0)
	return level + (1.5 if attacking else 0.0)


## How easy the hero is to spot: crouching hides, running stands out.
func visibility_factor() -> float:
	if crouching:
		return 0.55
	return 1.2 if sprinting else 1.0


func _equip_wand() -> void:
	var skeleton: Skeleton3D = model.find_child("Skeleton3D", true, false)
	var hand := BoneAttachment3D.new()
	hand.name = "WandAttachment"
	hand.bone_name = HAND_BONE
	skeleton.add_child(hand)
	hand.add_child(WAND_SCENE.instantiate())
	_shield.wand = hand
	_hand = hand


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_pivot.rotation.y -= event.relative.x * mouse_sensitivity
		camera_pivot.rotation.x = clampf(
			camera_pivot.rotation.x - event.relative.y * mouse_sensitivity,
			deg_to_rad(-70.0),
			deg_to_rad(30.0),
		)

	if event is InputEventMouseButton and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_handle_zoom(event)

	if event.is_action_pressed("move_forward"):
		_register_forward_tap()
	if event.is_action_released("move_forward"):
		_double_tap_sprint = false

	_forward_cast_button(event, "attack", _primary_attack)
	_forward_cast_button(event, "cast_secondary", _secondary_attack)
	if event.is_action_pressed("interact") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_interact()

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Presses only count while the mouse is captured; releases always do, so a held spell never sticks.
func _forward_cast_button(event: InputEvent, action: String, spell: SpellAttack) -> void:
	if event.is_action_released(action):
		spell.release()
	if event.is_action_pressed(action) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		spell.begin()


func _equip_spell(element: Element) -> SpellAttack:
	var spell := element.create_attack()
	spell.caster = self
	add_child(spell)
	return spell


## Loots the nearest corpse in reach, if there is one.
func _interact() -> void:
	var nearest: Animal = null
	var nearest_distance := INTERACT_RANGE
	for animal: Animal in get_tree().get_nodes_in_group("lootable"):
		var distance := global_position.distance_to(animal.global_position)
		if distance >= nearest_distance:
			continue
		nearest = animal
		nearest_distance = distance
	if nearest != null:
		nearest.interact(self)


func _register_forward_tap() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	_double_tap_sprint = now - _last_forward_tap < DOUBLE_TAP_WINDOW
	_last_forward_tap = now


func _handle_zoom(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			target_zoom = clampf(target_zoom - zoom_step, zoom_min, zoom_max)
		MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom = clampf(target_zoom + zoom_step, zoom_min, zoom_max)


func _process(delta: float) -> void:
	_place_shield()
	spring_arm.spring_length = lerpf(
		spring_arm.spring_length,
		target_zoom,
		1.0 - exp(-zoom_smoothing * delta),
	)
	var pivot_y := _pivot_rest_y - (crouch_camera_drop if crouching else 0.0)
	camera_pivot.position.y = lerpf(camera_pivot.position.y, pivot_y, 1.0 - exp(-10.0 * delta))


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		var gravity := get_gravity() * gravity_scale
		if velocity.y < 0.0:
			gravity *= fall_multiplier
		velocity += gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	_update_stance()

	# There is no attack-while-moving animation, so a grounded attack roots the player. In the
	# air the attack plays on top of the jump and movement carries on. Blocking roots too: the
	# hero only turns towards the camera, never walks.
	var rooted := (attacking or blocking) and is_on_floor()
	var input_dir := Vector2.ZERO if rooted else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var yaw_basis := Basis(Vector3.UP, camera_pivot.rotation.y)
	var direction := (yaw_basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	var move_speed := _move_speed()
	if direction:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		# Model's visual front is its local +Z (scene has it flipped 180 degrees)
		var target_yaw := atan2(direction.x, direction.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_yaw, turn_speed * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)

	_update_stamina(delta, direction != Vector3.ZERO)
	_update_mana(delta)
	_regen_health(delta)
	_tick_cast(delta)

	if blocking or attacking:
		# Guard and spells go where the camera looks, so the hero turns to face it.
		model.rotation.y = lerp_angle(model.rotation.y, camera_pivot.rotation.y + PI, turn_speed * delta)

	_step_up(delta)
	move_and_slide()
	_update_animation()


## Holds the circle in front of the hero, facing along the camera.
func _place_shield() -> void:
	var yaw := camera_pivot.rotation.y
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var height := SHIELD_HEIGHT - (crouch_camera_drop if crouching else 0.0)
	_shield.position = forward * SHIELD_DISTANCE + Vector3.UP * height
	_shield.rotation.y = yaw


func _update_stance() -> void:
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	blocking = captured and not attacking and Input.is_action_pressed("block")
	_set_crouching(Input.is_action_pressed("crouch"))
	var wants_sprint := Input.is_action_pressed("sprint") or _double_tap_sprint
	sprinting = wants_sprint and not crouching and not blocking and not exhausted


## Sprinting drains stamina. After a short pause it comes back slowly while walking and fast
## while standing still. Running dry exhausts the hero until a chunk has recovered.
func _update_stamina(delta: float, moving: bool) -> void:
	var before := stamina
	var was_exhausted := exhausted
	if sprinting and moving:
		stamina = maxf(stamina - sprint_drain * delta, 0.0)
		_regen_timer = regen_delay
	else:
		_regen_timer = maxf(_regen_timer - delta, 0.0)
		var regen := walk_regen if moving else idle_regen
		stamina = stamina if _regen_timer > 0.0 else minf(stamina + regen * delta, max_stamina)

	exhausted = stamina <= 0.0 or (exhausted and stamina < max_stamina * exhausted_recover)
	_double_tap_sprint = _double_tap_sprint and not exhausted
	if not is_equal_approx(before, stamina) or exhausted != was_exhausted:
		stamina_changed.emit(stamina, max_stamina, exhausted)


func _move_speed() -> float:
	if blocking:
		return speed * block_multiplier
	if crouching:
		return speed * crouch_multiplier
	if sprinting:
		return speed * sprint_multiplier
	return speed


## Shrinks the body while crouched; stands back up only if there is headroom for it.
func _set_crouching(want: bool) -> void:
	if want == crouching:
		return
	if not want and test_move(global_transform, Vector3.UP * (_stand_height - crouch_height)):
		return
	crouching = want
	var height := crouch_height if want else _stand_height
	(body_shape.shape as CapsuleShape3D).height = height
	body_shape.position.y = _stand_center_y - (_stand_height - height) * 0.5


## Lifts the body onto a low ledge in front of it, since CharacterBody3D has no step support.
func _step_up(delta: float) -> void:
	var motion := Vector3(velocity.x, 0.0, velocity.z) * delta
	if not is_on_floor() or motion.is_zero_approx():
		return

	var hit := KinematicCollision3D.new()
	if not test_move(global_transform, motion, hit) or hit.get_normal().y >= cos(floor_max_angle):
		return  # nothing in the way, or it is a walkable slope
	if (hit.get_collider() as Node).is_in_group(Kit.NO_STEP_GROUP):
		return  # logs and stumps stop the hero even though they are low

	# Probe far enough ahead that the whole capsule sits over the ledge top.
	var probe := motion.normalized() * STEP_PROBE_DISTANCE
	var raised := global_transform.translated(Vector3.UP * max_step_height)
	if test_move(raised, probe):
		return  # obstacle is taller than a step

	var landing := KinematicCollision3D.new()
	if not test_move(raised.translated(probe), Vector3.DOWN * max_step_height, landing):
		return  # no ground on top of the ledge
	if landing.get_normal().y < 0.5:
		return

	var rise := max_step_height - landing.get_travel().length()
	if rise > 0.01:
		global_position.y += rise


func _regen_health(delta: float) -> void:
	_since_hurt += delta
	if _since_hurt > regen_after:
		health.heal(health_regen * delta)


## Spends mana if there is enough. Mana only comes back a moment after the last cast.
func spend_mana(amount: float) -> bool:
	if mana < amount:
		return false
	mana -= amount
	_mana_timer = mana_regen_delay
	mana_changed.emit(mana, max_mana)
	return true


func _update_mana(delta: float) -> void:
	_mana_timer = maxf(_mana_timer - delta, 0.0)
	if _mana_timer > 0.0 or mana >= max_mana:
		return
	mana = minf(mana + mana_regen * delta, max_mana)
	mana_changed.emit(mana, max_mana)


## Starts a cast animation and roots the hero on the ground while it lasts: [param lock] seconds,
## 0 for the length of the animation, INF until [method release_cast] or [method end_cast].
## With [param hold_at] the pose freezes at that point of the animation. Returns false while
## another cast or the guard is busy.
func begin_cast(animation: String, lock := 0.0, speed := 1.0, hold_at := 0.0) -> bool:
	if attacking or blocking:
		return false
	attacking = true
	_double_tap_sprint = false
	_cast_anim = animation
	_cast_lock = lock
	_hold_at = hold_at
	anim.play(animation, 0.1, speed)
	return true


## Ends a held cast with its release animation, rooting the hero for [param lock] more seconds.
func release_cast(animation: String, lock: float, speed := 1.0) -> void:
	_cast_anim = animation
	_cast_lock = lock
	_hold_at = 0.0
	anim.play(animation, 0.08, speed)


func end_cast() -> void:
	attacking = false
	_cast_lock = 0.0
	_hold_at = 0.0


func _tick_cast(delta: float) -> void:
	_hold_pose()
	if not attacking or _cast_lock <= 0.0:
		return
	_cast_lock -= delta
	attacking = _cast_lock > 0.0


func _hold_pose() -> void:
	if _hold_at <= 0.0 or not anim.is_playing() or anim.current_animation_position < _hold_at:
		return
	anim.pause()
	_hold_at = 0.0


## Where the camera is looking: the first thing in the way, or far ahead if there is none.
func aim_point(reach := 150.0) -> Vector3:
	var origin := camera.global_position
	var forward := -camera.global_basis.z
	var hit := Combat.raycast(self, origin + forward, origin + forward * reach, [get_rid()])
	return origin + forward * reach if hit.is_empty() else hit["position"]


## Tip of the wand, where spells leave from.
func cast_origin() -> Vector3:
	return _hand.global_position


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == _cast_anim and _cast_lock <= 0.0:
		attacking = false


func _update_animation() -> void:
	if attacking:
		return

	var moving := Vector2(velocity.x, velocity.z).length() > 0.1
	var target: String
	if blocking:
		target = ANIM_BLOCK
	elif not is_on_floor():
		target = ANIM_AIR
	elif moving and crouching:
		target = ANIM_SNEAK
	elif moving and sprinting:
		target = ANIM_RUN
	elif moving:
		target = ANIM_WALK
	elif crouching:
		target = ANIM_CROUCH
	else:
		target = ANIM_IDLE

	if anim.current_animation != target:
		anim.play(target, 0.2)  # 0.2s crossfade
