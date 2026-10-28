extends CharacterBody3D

@export var speed: float = 4.5
@export var sprint_multiplier: float = 1.7
@export var crouch_multiplier: float = 0.45
@export var block_multiplier: float = 0.5
@export var crouch_height: float = 1.7
@export var crouch_camera_drop: float = 0.5
@export var jump_velocity: float = 9.0
@export var gravity_scale: float = 2.2
@export var fall_multiplier: float = 1.3
@export var mouse_sensitivity: float = 0.003
@export var turn_speed: float = 10.0
@export var max_step_height: float = 1.0
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
const LOOPED_ANIMS := [ANIM_WALK, ANIM_CROUCH, ANIM_SNEAK, ANIM_BLOCK]
const ANIM_AIR := "Rig_Medium_MovementBasic/Jump_Idle"
const ANIM_ATTACK := "Rig_Medium_General/Throw"

const WAND_SCENE := preload("res://assets/models/kaykit/wand.gltf")
const HAND_BONE := "handslot.r"

const STEP_PROBE_DISTANCE := 0.5
## Two forward taps within this many seconds start a sprint that lasts until forward is released.
const DOUBLE_TAP_WINDOW := 0.3

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var model: Node3D = $Model
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var body_shape: CollisionShape3D = $CollisionShape3D

var attacking := false
var blocking := false
var crouching := false
var sprinting := false
var _last_forward_tap := -1000.0
var _double_tap_sprint := false
var target_zoom: float
var _stand_height: float
var _stand_center_y: float
var _pivot_rest_y: float


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	target_zoom = spring_arm.spring_length
	_stand_height = (body_shape.shape as CapsuleShape3D).height
	_stand_center_y = body_shape.position.y
	_pivot_rest_y = camera_pivot.position.y
	for anim_name in LOOPED_ANIMS:
		anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	floor_snap_length = 0.4  # stick to the ground when walking down banks and steps
	anim.animation_finished.connect(_on_animation_finished)
	_equip_wand()


func _equip_wand() -> void:
	var skeleton: Skeleton3D = model.find_child("Skeleton3D", true, false)
	var hand := BoneAttachment3D.new()
	hand.name = "WandAttachment"
	hand.bone_name = HAND_BONE
	skeleton.add_child(hand)
	hand.add_child(WAND_SCENE.instantiate())


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

	if event.is_action_pressed("attack") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_attack()

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


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
	# air the attack plays on top of the jump and movement carries on.
	var rooted := attacking and is_on_floor()
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

	if blocking:
		# Keep the guard up towards where the camera looks, strafing instead of turning.
		model.rotation.y = lerp_angle(model.rotation.y, camera_pivot.rotation.y + PI, turn_speed * delta)

	_step_up(delta)
	move_and_slide()
	_update_animation()


func _update_stance() -> void:
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	blocking = captured and not attacking and Input.is_action_pressed("block")
	_set_crouching(Input.is_action_pressed("crouch"))
	sprinting = (Input.is_action_pressed("sprint") or _double_tap_sprint) and not crouching and not blocking


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


func _attack() -> void:
	if attacking or blocking:
		return
	attacking = true
	_double_tap_sprint = false
	anim.play(ANIM_ATTACK, 0.1)


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == ANIM_ATTACK:
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
