extends CharacterBody3D

@export var speed: float = 6.0
@export var jump_velocity: float = 5.0
@export var mouse_sensitivity: float = 0.003
@export var turn_speed: float = 10.0

const ANIM_IDLE := "Rig_Medium_General/Idle_A"
const ANIM_RUN := "Rig_Medium_MovementBasic/Running_A"
const ANIM_AIR := "Rig_Medium_MovementBasic/Jump_Idle"
const ANIM_ATTACK := "Rig_Medium_General/Throw"

const WAND_SCENE := preload("res://assets/models/kaykit/wand.gltf")
const HAND_BONE := "handslot.r"

@onready var camera_pivot: Node3D = $CameraPivot
@onready var model: Node3D = $Model
@onready var anim: AnimationPlayer = $AnimationPlayer

var attacking := false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
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

	if event.is_action_pressed("attack") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_attack()

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var yaw_basis := Basis(Vector3.UP, camera_pivot.rotation.y)
	var direction := (yaw_basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		# Model's visual front is its local +Z (scene has it flipped 180 degrees)
		var target_yaw := atan2(direction.x, direction.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_yaw, turn_speed * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

	move_and_slide()
	_update_animation()


func _attack() -> void:
	if attacking:
		return
	attacking = true
	anim.play(ANIM_ATTACK, 0.1)


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == ANIM_ATTACK:
		attacking = false


func _update_animation() -> void:
	if attacking:
		return

	var target: String
	if not is_on_floor():
		target = ANIM_AIR
	elif Vector2(velocity.x, velocity.z).length() > 0.1:
		target = ANIM_RUN
	else:
		target = ANIM_IDLE

	if anim.current_animation != target:
		anim.play(target, 0.2)  # 0.2s crossfade
