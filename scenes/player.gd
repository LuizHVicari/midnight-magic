class_name Player
extends CharacterBody3D

@export var speed: float = 4.5
@export var sprint_multiplier: float = 1.7
@export var crouch_multiplier: float = 0.45
@export var block_multiplier: float = 0.5
@export var cast_multiplier: float = 0.7
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
## Elements the hero can switch between, in order; for now all of them. Loaded at startup rather
## than preloaded: an element points to its attack script, which points back to the player.
@export var element_paths: PackedStringArray = [
	"res://scenes/combat/elements/light.tres",
	"res://scenes/combat/elements/fire.tres",
	"res://scenes/combat/elements/wind.tres",
	"res://scenes/combat/elements/water.tres",
	"res://scenes/combat/elements/earth.tres",
	"res://scenes/combat/elements/shadow.tres",
]
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
const ANIM_BACKWARD := "Rig_Medium_MovementAdvanced/Walking_Backwards"
const ANIM_STRAFE_LEFT := "Rig_Medium_MovementAdvanced/Running_Strafe_Left"
const ANIM_STRAFE_RIGHT := "Rig_Medium_MovementAdvanced/Running_Strafe_Right"
const ANIM_BLOCK := "Rig_Medium_CombatMelee/Melee_Blocking"
const ANIM_CHANNEL := "Rig_Medium_CombatRanged/Ranged_Magic_Raise"
## Second into the raise where the wand is up and steady; a held cast freezes there.
const CHANNEL_HOLD := 1.1
const ANIM_THROW := "Rig_Medium_General/Throw"
const LOOPED_ANIMS := [ANIM_WALK, ANIM_CROUCH, ANIM_SNEAK, ANIM_BLOCK, ANIM_BACKWARD, ANIM_STRAFE_LEFT, ANIM_STRAFE_RIGHT]
## Guard and casts play on their own layer with only these bones, so the legs keep walking.
const UPPER_ANIMS := [ANIM_BLOCK, ANIM_CHANNEL, ANIM_THROW]
const LOWER_BONES := ["root", "hips", "upperleg", "lowerleg", "foot", "toes"]
const UPPER_LIBRARY := &"Upper"
const GLIDE_POSE := &"Glide"
## Playback speed of the sideways run while only walking.
const STRAFE_WALK_SPEED := 0.7
const BACKWARD_SPEED := 0.8
## Playback speed of the sideways and backwards steps while crouched, which there is no pose for.
const CROUCH_STEP_SPEED := 0.55
const ANIM_AIR := "Rig_Medium_MovementBasic/Jump_Idle"
const ANIM_LAND := "Rig_Medium_MovementBasic/Jump_Land"
## Landing at least this fast (m/s) makes the hero crouch for a moment, hurt or not.
const HARD_LANDING := 12.0
const LANDING_TIME := 0.4
## How hard an updraft pushes the hero upwards (m/s^2).
const LIFT_ACCEL := 70.0

signal stamina_changed(value: float, maximum: float, exhausted: bool)
signal mana_changed(value: float, maximum: float)
signal item_collected(item: String, count: int)
signal leveled_up(level: int)
signal element_changed(element: Element)
signal loadout_changed
## The guard circle broke; it can be raised again after [param cooldown] seconds.
signal shield_broken(cooldown: float)

const WAND_SCENE := preload("res://assets/models/kaykit/wand.gltf")
const HAND_BONE := "handslot.r"

const STEP_PROBE_DISTANCE := 0.5
const LOOT_COLOR := Color(1.0, 0.82, 0.35)
const XP_COLOR := Color(0.5, 0.9, 0.85)
## Share of the damage of a blocked hit that gets through.
const BLOCK_TAKEN := 0.3
## The guard circle holds this much damage before it breaks, then cannot be raised for a while.
## It mends itself slowly once nothing has hit it for a few seconds.
## Gliding: falling slowly while holding the glide spell, and gliding forward at this speed.
const GLIDE_FALL := 2.2
const GLIDE_SPEED := 9.5
const GLIDE_GRAVITY := 0.25  # share of gravity left while gliding
const GLIDE_TILT := 0.95  # radians the body leans forward
## The hero's hips above their feet, which the lean pivots around.
const HIPS := Vector3(0.0, 1.0, 0.0)
## How fast a shove (from a bomb, say) fades, per second, on the ground, in the air and gliding.
const SHOVE_DRAG := Vector3(7.0, 0.6, 0.35)
const MAX_SHOVE := 26.0
## The breeze cloak: footsteps this loud, and a walk this much faster.
const BREEZE_NOISE := 0.3
const BREEZE_SPEED := 1.35
## Quick slots: the primary button first, then the four ability keys. Any ability of the equipped
## element can sit in any of them.
const SLOT_ACTIONS: Array[String] = ["attack", "ability_1", "ability_2", "ability_3", "ability_4", "ability_5"]
const SHIELD_MAX := 80.0
const SHIELD_MEND := 8.0  # integrity per second
const SHIELD_MEND_AFTER := 3.0
const SHIELD_COOLDOWN := 8.0
## What each level adds to the hero.
const LEVEL_HEALTH := 12.0
const LEVEL_MANA := 8.0
const LEVEL_STAMINA := 6.0
const LEVEL_POWER := 0.08  # share of extra spell damage per level
## Hits below this share of max health do not flash the screen or shake the camera (burn ticks).
const HURT_MIN_SHARE := 0.03
const HURT_FLASH := 5.0  # flash strength per share of max health lost
const HURT_SHAKE := 2.2  # camera offset (m) per share of max health lost
const HURT_SHAKE_MAX := 0.35
const SHAKE_DECAY := 1.6
## How close the hero has to be to a corpse to loot it.
const INTERACT_RANGE := 3.0
const SHIELD_DISTANCE := 1.6
const SHIELD_HEIGHT := 1.2
## Two forward taps within this many seconds start a sprint that lasts until forward is released.
const DOUBLE_TAP_WINDOW := 0.3

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var model: Node3D = $Model
## Legs and idle poses: the body underneath everything else.
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
var level := 1
var xp := 0
var _since_hurt := 0.0
var _shake := 0.0
var _regen_timer := 0.0
var _mana_timer := 0.0
var _cast_anim := ""
var _cast_lock := 0.0  # seconds the cast still roots the hero; 0 = until its animation ends
var _hold_at := 0.0  # animation position where the cast pose freezes; 0 = never
var _hand: Node3D
var elements: Array[Element] = []
var current_element: Element
var _element_index := 0
var _pressed_ability: SpellAttack
## What is in the quick slots of each element: Element -> Array[Ability] (null = empty slot).
var _loadouts := {}
var _actions := {}  # Ability -> SpellAttack, made the first time it is used
## True while the beam spell carries the hero along a path; nothing can hurt or steer them.
var dashing := false
## How many lights of the hero's own (like the sentinel orb) are burning; they make the hero
## easier for foes to notice.
var glow_sources := 0
## True while the glide spell holds the hero up in the air.
var gliding := false
## Seconds left of the breeze cloak: quiet footsteps and a faster walk.
var breeze_left := 0.0
## Seconds left of being quiet after a shadow step at night: footsteps carry much less.
var hush_left := 0.0
## Seconds left of being lit by a burst of light: it shows up even through a blackout.
var lit_left := 0.0
var _air_speed := 0.0  # how fast the hero was falling a moment ago
var _landing_left := 0.0
var _shove := Vector3.ZERO  # sideways speed from shoves; fades, and adds to walking
var _lean := 0.0
var _dash_from := Vector3.ZERO
var _dash_to := Vector3.ZERO
var _dash_time := 0.1
var _dash_clock := 0.0
var _outfit := HeroOutfit.new()
var _last_forward_tap := -1000.0
var _double_tap_sprint := false
var target_zoom: float
var _shield := MagicShield.new()
var _shield_integrity := SHIELD_MAX
var _shield_cooldown := 0.0
var _since_shield_hit := 0.0
## Arms, torso and head of the guard and casts, drawn over [member anim].
var _upper := AnimationPlayer.new()
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
	_setup_progress()
	for path in element_paths:
		elements.append(load(path) as Element)
	_outfit.setup(model)
	_build_loadouts()
	_select_element(0)
	$Hud.show_abilities(self)
	for anim_name in LOOPED_ANIMS:
		anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	floor_snap_length = 0.4  # stick to the ground when walking down banks and steps
	_build_upper_layer()
	_upper.animation_finished.connect(_on_animation_finished)
	_equip_wand()
	add_child(_shield)


## Copies the guard and cast animations without their leg and hip tracks into a second player.
## It sits after [member anim] in the tree, so while it plays it wins the bones they share.
func _build_upper_layer() -> void:
	_upper.name = "UpperBody"
	_upper.root_node = anim.root_node
	var library := AnimationLibrary.new()
	for path: String in UPPER_ANIMS:
		library.add_animation(_upper_name(path), _upper_clip(anim.get_animation(path)))
	var skeleton: Skeleton3D = model.find_child("Skeleton3D", true, false)
	library.add_animation(GLIDE_POSE, GlidePose.build(skeleton, str(model.get_path_to(skeleton))))
	_upper.add_animation_library(UPPER_LIBRARY, library)
	add_child(_upper)


func _upper_clip(full: Animation) -> Animation:
	var clip := full.duplicate() as Animation
	for track in range(clip.get_track_count() - 1, -1, -1):
		if _is_lower_bone(clip.track_get_path(track).get_concatenated_subnames()):
			clip.remove_track(track)
	return clip


func _is_lower_bone(bone: String) -> bool:
	return LOWER_BONES.any(func(part: String) -> bool: return bone.begins_with(part))


func _upper_name(path: String) -> StringName:
	return StringName(path.get_file())


## The name [member _upper] knows an animation by: its library and the animation's own name.
func _upper_key(path: String) -> StringName:
	return StringName("%s/%s" % [UPPER_LIBRARY, _upper_name(path)])


func _play_upper(path: String, blend := 0.1, speed := 1.0) -> void:
	_upper.play(_upper_key(path), blend, speed)


func _build_health() -> void:
	health.name = "Health"
	health.maximum = max_health
	health.targetable = false  # spells never lock on to the hero
	health.hero = true
	health.damage_filter = _soften_blocked_hits
	add_child(health)
	health.changed.connect($Hud.add_bar(StatBar.Kind.HEALTH).set_value)
	health.changed.emit(health.value, health.maximum)
	health.damaged.connect(_on_hurt)
	health.pushed.connect(_on_shoved)
	health.died.connect(_on_died)


func _on_hurt(amount: float, _element: Element) -> void:
	_since_hurt = 0.0
	var share := amount / health.maximum
	if share < HURT_MIN_SHARE:
		return
	$Hud.flash(share * HURT_FLASH)
	_shake = maxf(_shake, minf(share * HURT_SHAKE, HURT_SHAKE_MAX))


## Camera jolt from a hit: a quick random wobble that dies away.
## Whether the hero gives off light of their own right now (an orb, a flash): that cuts through
## darkness.
func is_lit() -> bool:
	return glow_sources > 0 or lit_left > 0.0


## Shakes the camera for a moment, [param amount] in meters of offset (capped).
func shake(amount: float) -> void:
	_shake = maxf(_shake, minf(amount, HURT_SHAKE_MAX * 1.5))


func _apply_shake(delta: float) -> void:
	_shake = maxf(_shake - SHAKE_DECAY * delta, 0.0)
	camera.h_offset = randf_range(-1.0, 1.0) * _shake
	camera.v_offset = randf_range(-1.0, 1.0) * _shake


## Hits from the front while the guard is up land for a fraction of their damage.
func _soften_blocked_hits(amount: float, _element: Element, from: Vector3) -> float:
	if dashing:
		return 0.0
	if not blocking or from == Vector3.INF:
		return amount
	var forward := Vector3(-sin(camera_pivot.rotation.y), 0.0, -cos(camera_pivot.rotation.y))
	var toward := from - global_position
	toward.y = 0.0
	if forward.angle_to(toward) >= deg_to_rad(75.0):
		return amount
	return _absorb(amount)


## The circle takes the hit: the hero only feels a fraction of it, and whatever is more than the
## circle had left gets through whole. Out of integrity, it shatters.
func _absorb(amount: float) -> float:
	var held := minf(amount, _shield_integrity)
	_shield_integrity -= held
	_since_shield_hit = 0.0
	_shield.set_damage(1.0 - _shield_integrity / SHIELD_MAX)
	if _shield_integrity <= 0.0:
		_break_shield()
	return held * BLOCK_TAKEN + (amount - held)


func _break_shield() -> void:
	_shield_cooldown = SHIELD_COOLDOWN
	_shield.shatter()
	shield_broken.emit(SHIELD_COOLDOWN)


## Mends the circle while it is not being hit and counts the cooldown after it broke.
func _tick_shield(delta: float) -> void:
	_since_shield_hit += delta
	if _shield_cooldown > 0.0:
		_shield_cooldown = maxf(_shield_cooldown - delta, 0.0)
		_shield_integrity = SHIELD_MAX if _shield_cooldown <= 0.0 else 0.0
		return
	if _since_shield_hit < SHIELD_MEND_AFTER or _shield_integrity >= SHIELD_MAX:
		return
	_shield_integrity = minf(_shield_integrity + SHIELD_MEND * delta, SHIELD_MAX)
	_shield.set_damage(1.0 - _shield_integrity / SHIELD_MAX)


# --- level, experience and coins ---------------------------------------------------------------

## Experience needed to get from [param at_level] to the next one.
static func xp_for(at_level: int) -> int:
	return int(40.0 * pow(at_level, 1.4))


func _setup_progress() -> void:
	Health.spell_power = 1.0
	var badge: ProgressBadge = $Hud.badge()
	badge.set_level(level)
	badge.set_xp(xp, xp_for(level))
	badge.set_coins(0)
	item_collected.connect(func(item: String, _count: int) -> void: badge.set_coins(int(inventory.get("Coins", 0))))
	leveled_up.connect(func(new_level: int) -> void: badge.set_level(new_level, true))


## Experience from a kill. Leveling up makes the hero tougher and their spells stronger.
func gain_xp(amount: int) -> void:
	xp += amount
	DamagePopup.spawn(get_parent(), global_position + Vector3.UP * 3.3, "+%d XP" % amount, XP_COLOR)
	while xp >= xp_for(level):
		xp -= xp_for(level)
		_level_up()
	var badge: ProgressBadge = $Hud.badge()
	badge.set_xp(xp, xp_for(level))


func _level_up() -> void:
	level += 1
	max_health += LEVEL_HEALTH
	max_mana += LEVEL_MANA
	max_stamina += LEVEL_STAMINA
	Health.spell_power = 1.0 + LEVEL_POWER * (level - 1)
	health.maximum = max_health
	health.restore()
	mana = max_mana
	stamina = max_stamina
	mana_changed.emit(mana, max_mana)
	stamina_changed.emit(stamina, max_stamina, exhausted)
	DamagePopup.spawn(get_parent(), global_position + Vector3.UP * 3.9, "LEVEL %d!" % level, Color(1.0, 0.9, 0.4))
	leveled_up.emit(level)


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
	var noise := level + (1.5 if attacking else 0.0)
	return noise * (BREEZE_NOISE if breeze_left > 0.0 or hush_left > 0.0 else 1.0)


## Points of the body that enemies try to see: head and chest. Crouching lowers them, so low
## cover (a log, a rock) can hide a crouching hero completely and a standing one only partly.
func cover_points() -> PackedVector3Array:
	var heights := [0.45, 1.15] if crouching else [0.9, 2.0]
	return PackedVector3Array([global_position + Vector3.UP * heights[0], global_position + Vector3.UP * heights[1]])


## How easy the hero is to spot: crouching hides, running stands out.
func visibility_factor() -> float:
	var glow := 1.3 if glow_sources > 0 else 1.0
	if crouching:
		return 0.55 * glow
	return (1.2 if sprinting else 1.0) * glow


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

	_forward_ability_keys(event)
	if event.is_action_pressed("switch_element"):
		switch_element(1)
	if event.is_action_pressed("interact") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_interact()

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## The quick-slot buttons fire the ability in their slot, for the equipped element. Presses only
## count while the mouse is captured; releases always do, so a held spell never sticks. The
## release goes to the spell that was started, whatever is equipped by then.
func _forward_ability_keys(event: InputEvent) -> void:
	for slot in SLOT_ACTIONS.size():
		var action := SLOT_ACTIONS[slot]
		if event.is_action_released(action) and _pressed_ability != null:
			_pressed_ability.release()
			_pressed_ability = null
		if event.is_action_pressed(action) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_use_slot(slot)


func _use_slot(slot: int) -> void:
	var ability := slot_ability(slot)
	if ability == null or dashing:
		return
	_pressed_ability = _action_for(ability)
	_pressed_ability.begin()


## The ability in a quick slot of the equipped element, or null if it is empty.
func slot_ability(slot: int) -> Ability:
	var slots: Array = _loadouts[current_element]
	return slots[slot]


## The running action of an ability, for reading its cooldown. Null if it was never used.
func ability_action(ability: Ability) -> SpellAttack:
	return _actions.get(ability)


func _action_for(ability: Ability) -> SpellAttack:
	if not _actions.has(ability):
		var action := ability.create_action(current_element)
		action.caster = self
		add_child(action)
		_actions[ability] = action
	return _actions[ability]


## Every element starts with its basic attack on the primary button and its first abilities on
## the keys, in order.
func _build_loadouts() -> void:
	for each in elements:
		var book := each.spellbook()
		var slots: Array[Ability] = []
		slots.resize(SLOT_ACTIONS.size())
		for i in mini(SLOT_ACTIONS.size(), book.size()):
			slots[i] = book[i]
		_loadouts[each] = slots


## Moves [param step] places along the element list (wrapping). Not while a spell is being cast.
func switch_element(step: int) -> void:
	if attacking or dashing or step == 0:
		return
	_select_element(posmod(_element_index + step, elements.size()))
	DamagePopup.spawn(get_parent(), global_position + Vector3.UP * 3.3, current_element.display_name, current_element.color)


func _select_element(index: int) -> void:
	_element_index = index
	current_element = elements[index]
	_outfit.dress(current_element)
	element_changed.emit(current_element)


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
	_apply_shake(delta)
	_tick_shield(delta)
	breeze_left = maxf(breeze_left - delta, 0.0)
	hush_left = maxf(hush_left - delta, 0.0)
	lit_left = maxf(lit_left - delta, 0.0)
	$Hud.set_darkness(BlackoutZone.contains(get_tree(), global_position))
	spring_arm.spring_length = lerpf(
		spring_arm.spring_length,
		target_zoom,
		1.0 - exp(-zoom_smoothing * delta),
	)
	var pivot_y := _pivot_rest_y - (crouch_camera_drop if crouching else 0.0)
	camera_pivot.position.y = lerpf(camera_pivot.position.y, pivot_y, 1.0 - exp(-10.0 * delta))


func _physics_process(delta: float) -> void:
	if dashing:
		_step_dash(delta)
		return
	_landing_left = maxf(_landing_left - delta, 0.0)
	_track_landing()
	if gliding and is_on_floor():
		gliding = false
	if gliding:
		_glide_fall(delta)
	elif not is_on_floor():
		var gravity := get_gravity() * gravity_scale
		if velocity.y < 0.0:
			gravity *= fall_multiplier
		velocity += gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	_update_stance()

	# Guard and casts only use the upper body, so the hero keeps walking (slower) through them.
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var yaw_basis := Basis(Vector3.UP, camera_pivot.rotation.y)
	var direction := (yaw_basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	if gliding and direction == Vector3.ZERO:
		direction = yaw_basis * Vector3.FORWARD  # a glide keeps moving the way the camera looks

	var move_speed := _move_speed()
	_fade_shove(delta)
	if direction:
		velocity.x = direction.x * move_speed + _shove.x
		velocity.z = direction.z * move_speed + _shove.z
		# Model's visual front is its local +Z (scene has it flipped 180 degrees). Aiming keeps
		# it facing the camera instead, and the legs walk backwards or sideways.
		var target_yaw := atan2(direction.x, direction.z)
		_turn_towards_movement(target_yaw, delta)
	else:
		velocity.x = _shove.x
		velocity.z = _shove.z

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
	_update_lean(delta)


func _turn_towards_movement(target_yaw: float, delta: float) -> void:
	if blocking or attacking:
		return
	model.rotation.y = lerp_angle(model.rotation.y, target_yaw, turn_speed * delta)


## Holds the circle in front of the hero, facing along the camera.
func _place_shield() -> void:
	var yaw := camera_pivot.rotation.y
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var height := SHIELD_HEIGHT - (crouch_camera_drop if crouching else 0.0)
	_shield.position = forward * SHIELD_DISTANCE + Vector3.UP * height
	_shield.rotation.y = yaw


func _update_stance() -> void:
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	blocking = captured and not attacking and _shield_cooldown <= 0.0 and Input.is_action_pressed("block")
	_set_crouching(Input.is_action_pressed("crouch"))
	var wants_sprint := Input.is_action_pressed("sprint") or _double_tap_sprint
	sprinting = wants_sprint and not crouching and not blocking and not attacking and not exhausted


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
	if gliding:
		return GLIDE_SPEED
	if _landing_left > 0.0:
		return speed * 0.5
	# Stance and activity stack: crouching while casting is slower than either alone.
	var factor := 1.0
	factor *= BREEZE_SPEED if breeze_left > 0.0 else 1.0
	factor *= crouch_multiplier if crouching else 1.0
	factor *= block_multiplier if blocking else 1.0
	factor *= cast_multiplier if attacking else 1.0
	factor *= sprint_multiplier if sprinting else 1.0
	return speed * factor


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
	if attacking or blocking or dashing:
		return false
	attacking = true
	_double_tap_sprint = false
	_cast_anim = animation
	_cast_lock = lock
	_hold_at = hold_at
	_play_upper(animation, 0.1, speed)
	return true


## Ends a held cast with its release animation, rooting the hero for [param lock] more seconds.
func release_cast(animation: String, lock: float, speed := 1.0) -> void:
	_cast_anim = animation
	_cast_lock = lock
	_hold_at = 0.0
	_play_upper(animation, 0.08, speed)


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
	if _hold_at <= 0.0 or not _upper.is_playing() or _upper.current_animation_position < _hold_at:
		return
	_upper.pause()
	_hold_at = 0.0


## A push from something (a wind bomb, a blast): the vertical part goes straight into the fall or
## the climb, the sideways part is kept as speed that wears off. Pushing up cancels a fall first,
## so a bomb underfoot always lifts.
func _on_shoved(shove: Vector3) -> void:
	_shove += Vector3(shove.x, 0.0, shove.z)
	_shove = _shove.limit_length(MAX_SHOVE)
	velocity.y = (maxf(velocity.y, 0.0) if shove.y > 0.0 else velocity.y) + shove.y


func _fade_shove(delta: float) -> void:
	var drag := SHOVE_DRAG.z if gliding else (SHOVE_DRAG.x if is_on_floor() else SHOVE_DRAG.y)
	_shove *= exp(-drag * delta)
	if is_on_wall():
		_shove = _shove.slide(get_wall_normal())


## Remembers how fast the hero is falling and, on touching down, lets [Health] work out the hurt
## and plays a crouch for a hard landing.
func _track_landing() -> void:
	if not is_on_floor():
		_air_speed = maxf(-velocity.y, 0.0)
		return
	if _air_speed <= 0.0:
		return
	var speed := _air_speed
	_air_speed = 0.0
	var hurt := health.land(speed)
	if speed < HARD_LANDING and hurt <= 0.0:
		return
	_landing_left = LANDING_TIME
	anim.play(ANIM_LAND, 0.05, 1.6)
	_shake = maxf(_shake, minf(speed * 0.01, 0.25))


## An updraft carries the hero up: speeds up towards [param speed] (m/s) at [constant LIFT_ACCEL].
func lift(delta: float, speed: float) -> void:
	velocity.y = move_toward(velocity.y, speed, LIFT_ACCEL * delta)


## Starts a glide: only in the air, and held until [method end_glide]. False if the hero is on
## the ground or busy.
func begin_glide() -> bool:
	if gliding or dashing or is_on_floor():
		return false
	gliding = true
	return true


func end_glide() -> void:
	gliding = false


## Gravity is mostly cancelled: the fall is slowed down to a drift, and any climb eases off.
func _glide_fall(delta: float) -> void:
	velocity.y -= get_gravity().length() * gravity_scale * GLIDE_GRAVITY * delta
	if velocity.y < -GLIDE_FALL:
		velocity.y = move_toward(velocity.y, -GLIDE_FALL, 40.0 * delta)


## Leans the whole body forward while gliding, turning about the hips rather than the feet.
func _update_lean(delta: float) -> void:
	_lean = lerpf(_lean, GLIDE_TILT if gliding else 0.0, 1.0 - exp(-8.0 * delta))
	model.rotation.x = _lean
	model.position = HIPS - model.basis * HIPS


## Carries the hero to [param to] (their feet) in [param time] seconds, unseen and untouchable on
## the way. False if they are busy with something else.
func begin_dash(to: Vector3, time: float) -> bool:
	if dashing or attacking:
		return false
	_dash_from = global_position
	_dash_to = to
	_dash_time = time
	_dash_clock = 0.0
	dashing = true
	blocking = false
	_double_tap_sprint = false
	velocity = Vector3.ZERO
	model.visible = false
	return true


## How far along its path the dash is, 0 to 1 (eased, so it matches where the hero really is).
func dash_progress() -> float:
	return _dash_ease(_dash_clock / _dash_time)


func _dash_ease(share: float) -> float:
	return 1.0 - pow(1.0 - clampf(share, 0.0, 1.0), 2.0)


func _step_dash(delta: float) -> void:
	_dash_clock += delta
	global_position = _dash_from.lerp(_dash_to, dash_progress())
	if _dash_clock < _dash_time:
		return
	dashing = false
	model.visible = true
	var carry := (_dash_to - _dash_from).normalized() * speed * 0.8
	_shove = Vector3(carry.x, 0.0, carry.z)
	velocity.y = carry.y


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
	if anim_name == _upper_key(_cast_anim) and _cast_lock <= 0.0:
		attacking = false


func _update_animation() -> void:
	_update_legs()
	_update_upper()


## Locomotion for the whole body. While aiming the hero faces the camera, so moving sideways or
## backwards needs its own steps.
func _update_legs() -> void:
	if _landing_left > 0.0:
		return  # the landing crouch is playing
	var moving := Vector2(velocity.x, velocity.z).length() > 0.1
	var target := _locomotion(moving)
	anim.speed_scale = _locomotion_speed(target)
	if anim.current_animation != target:
		anim.play(target, 0.2)  # 0.2s crossfade


func _locomotion(moving: bool) -> String:
	if not is_on_floor():
		return ANIM_AIR
	if moving and (blocking or attacking):
		return _aiming_step(ANIM_SNEAK if crouching else ANIM_WALK)
	if moving and crouching:
		return ANIM_SNEAK
	if moving and sprinting:
		return ANIM_RUN
	if moving:
		return ANIM_WALK
	return ANIM_CROUCH if crouching else ANIM_IDLE


## Which way the feet go for the way the hero is moving relative to where the model faces.
func _aiming_step(forward_step: String) -> String:
	var facing := Vector3(sin(model.rotation.y), 0.0, cos(model.rotation.y))
	var ahead := Vector3(velocity.x, 0.0, velocity.z).dot(facing)
	var side := Vector3(velocity.x, 0.0, velocity.z).dot(facing.cross(Vector3.UP))
	if absf(side) > absf(ahead):
		return ANIM_STRAFE_RIGHT if side > 0.0 else ANIM_STRAFE_LEFT
	return forward_step if ahead > 0.0 else ANIM_BACKWARD


func _locomotion_speed(target: String) -> float:
	var sideways := target == ANIM_STRAFE_LEFT or target == ANIM_STRAFE_RIGHT
	var factor := STRAFE_WALK_SPEED if sideways else 1.0
	var steps_back := target == ANIM_BACKWARD
	factor *= BACKWARD_SPEED if steps_back and not crouching else 1.0
	return factor * (CROUCH_STEP_SPEED if crouching and (sideways or steps_back) else 1.0)


## Guard and casts over the legs; with neither active the layer is switched off.
func _update_upper() -> void:
	if attacking:
		return
	if blocking:
		_hold_guard()
		return
	if gliding:
		_hold_glide()
		return
	if _upper.current_animation != "":
		_upper.stop()


func _hold_glide() -> void:
	if _upper.is_playing() and _upper.current_animation.ends_with(GLIDE_POSE):
		return
	_upper.play("%s/%s" % [UPPER_LIBRARY, GLIDE_POSE], 0.25)


func _hold_guard() -> void:
	if _upper.is_playing() and _upper.current_animation.ends_with(_upper_name(ANIM_BLOCK)):
		return
	_play_upper(ANIM_BLOCK, 0.15)
