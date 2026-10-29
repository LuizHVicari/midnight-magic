class_name FoeCamp
extends Node3D
## The group of foes that lives at a camp. It spawns them around the fire, some sitting and some
## on guard, and makes the group act as one: when a member spots the hero the others hear it.
## When members die it brings new ones, but slowly (one per [constant RESTOCK_EVERY] seconds) and
## only while the hero is away and nobody is fighting, so a camp that was cleared stays quiet for a
## good while. Foes are as strong as the hero's level plus the camp's [member tier]: farther camps
## are tougher. Place it at the camp's center, on the ground.

const BANDIT := preload("res://scenes/wildlife/species/bandit.tres")
const ARCHER := preload("res://scenes/wildlife/species/archer.tres")
const BRUTE := preload("res://scenes/wildlife/species/brute.tres")

const RESTOCK_EVERY := 300.0
const SAFE_DISTANCE := 90.0
const CHECK_EVERY := 2.0
const START := Vector2(0.0, 430.0)
const TIER_STEP := 250.0  # meters from the start per tier

## Who lives here: {"species": FoeSpecies, "resting": bool}.
var roster: Array[Dictionary] = []
var tier := 0

var _slots: Array[Foe] = []
var _check := 0.0
var _restock_clock := 0.0


## A camp whose roster and tier come from how far it is from where the hero starts.
static func for_position(at: Vector2) -> FoeCamp:
	var camp := FoeCamp.new()
	camp.tier = int(at.distance_to(START) / TIER_STEP)
	camp.roster.append({"species": BANDIT, "resting": true})
	camp.roster.append({"species": BANDIT, "resting": false})
	camp.roster.append({"species": ARCHER, "resting": false})
	if camp.tier >= 1:
		camp.roster.append({"species": BRUTE, "resting": false})
	if camp.tier >= 2:
		camp.roster.append({"species": BANDIT, "resting": true})
	return camp


func _ready() -> void:
	_slots.resize(roster.size())
	# Let the camp's props register with the physics world before looking for free ground.
	await get_tree().physics_frame
	for i in roster.size():
		_spawn(i)


func _process(delta: float) -> void:
	_check += delta
	if _check < CHECK_EVERY:
		return
	var elapsed := _check
	_check = 0.0
	var missing := _missing()
	if missing.is_empty() or not _quiet():
		_restock_clock = 0.0 if missing.is_empty() else _restock_clock
		return
	_restock_clock += elapsed
	if _restock_clock >= RESTOCK_EVERY:
		_restock_clock = 0.0
		_spawn(missing[0])


## Called by a foe that has started fighting.
func raise_alarm(source: Foe, at: Vector3) -> void:
	for member in _slots:
		if member == null or not is_instance_valid(member) or member == source or member.dead:
			continue
		var distance := member.global_position.distance_to(source.global_position)
		if distance < Foe.ALARM_NEAR:
			member.hear_alarm(at, 1.0)
		elif distance < Foe.ALARM_FAR:
			member.hear_alarm(at, 0.7)


func living_count() -> int:
	return roster.size() - _missing().size()


## Slots with nobody alive in them.
func _missing() -> Array[int]:
	var missing: Array[int] = []
	for i in roster.size():
		var member := _slots[i]
		if member == null or not is_instance_valid(member) or member.dead:
			missing.append(i)
	return missing


## Whether a restock may run its clock: the hero is far away and nobody here is fighting.
func _quiet() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null and player.global_position.distance_to(global_position) < SAFE_DISTANCE:
		return false
	for member in _slots:
		if member != null and is_instance_valid(member) and not member.dead:
			if member.state == Foe.State.ENGAGE or member.state == Foe.State.ATTACK:
				return false
	return true


func _spawn(index: int) -> void:
	var entry := roster[index]
	var resting: bool = entry["resting"]
	var spot := _free_spot(3.0, 6.5) if resting else _free_spot(6.0, 13.0)
	if spot == Vector3.INF:
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	var foe := Foe.new()
	foe.species = entry["species"]
	foe.level = maxi(1, (player.level if player != null else 1) + tier)
	foe.camp = self
	foe.resting = resting
	foe.home = global_position
	foe.look_at_point = global_position
	foe.position = to_local(spot)
	add_child(foe)
	_slots[index] = foe


## A spot on the ground at the given distance from the fire where nothing stands: no tent, crate,
## log or tree, and not in water.
func _free_spot(near: float, far: float) -> Vector3:
	var terrain := get_tree().get_first_node_in_group("terrain") as Terrain
	var shape := CapsuleShape3D.new()
	shape.radius = 0.55
	shape.height = 1.7
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = Combat.WORLD | Combat.STONE
	for attempt in 24:
		var flat := Vector2.from_angle(randf() * TAU) * randf_range(near, far)
		var spot := global_position + Vector3(flat.x, 0.0, flat.y)
		spot.y = terrain.height_at(spot.x, spot.z)
		if terrain.is_water(spot.x, spot.z) or terrain.normal_at(spot.x, spot.z).y < 0.85:
			continue
		query.transform = Transform3D(Basis.IDENTITY, spot + Vector3.UP * 1.45)
		if get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
			return spot
	return Vector3.INF
