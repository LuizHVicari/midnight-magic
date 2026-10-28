extends CharacterBody3D

@export var speed: float = 6.0
@export var jump_velocity: float = 5.0
@export var mouse_sensitivity: float = 0.003

const ANIM_IDLE := "Rig_Medium_General/Idle_A"
const ANIM_RUN := "Rig_Medium_MovementBasic/Running_A"
const ANIM_AIR := "Rig_Medium_MovementBasic/Jump_Idle"

@onready var camera_pivot: Node3D = $CameraPivot
@onready var anim: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
		camera_pivot.rotation.x = clampf(
			camera_pivot.rotation.x, deg_to_rad(-70.0), deg_to_rad(30.0)
		)

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
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

	move_and_slide()
	_update_animation()


func _update_animation() -> void:
	var target: String
	if not is_on_floor():
		target = ANIM_AIR
	elif Vector2(velocity.x, velocity.z).length() > 0.1:
		target = ANIM_RUN
	else:
		target = ANIM_IDLE

	if anim.current_animation != target:
		anim.play(target, 0.2)  # 0.2s crossfade
