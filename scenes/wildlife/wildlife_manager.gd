class_name WildlifeManager
extends Node3D
## Decides which animals exist, the way Minecraft does: not placed by hand but spawned around the
## hero while they play. A few times a second it picks a species by its weight, picks a random
## spot in a ring around the hero, and spawns the species there if the spot suits it (terrain,
## water, trees, altitude, slope) and it has not reached its cap. Many species come in groups: a
## flock of birds, a family of ducks, a lone fox. Animals far from the hero are removed again.

const SPECIES := [
	preload("res://scenes/wildlife/species/rabbit.tres"),
	preload("res://scenes/wildlife/species/squirrel.tres"),
	preload("res://scenes/wildlife/species/fox.tres"),
	preload("res://scenes/wildlife/species/duck.tres"),
	preload("res://scenes/wildlife/species/owl.tres"),
	preload("res://scenes/wildlife/species/birds.tres"),
	preload("res://scenes/wildlife/species/eagle.tres"),
]

const MAX_TOTAL := 70
const SPAWN_EVERY := 1.0
const ATTEMPTS := 8
const FIRST_ATTEMPTS := 90  # fills the world the moment the game starts
const RING := Vector2(35.0, 130.0)  # spawn this far from the hero
const DESPAWN_RADIUS := 190.0
const TREE_RADIUS := 30.0
const VIEW_ANGLE := 55.0  # animals do not pop into existence inside this cone, when close
const VIEW_DISTANCE := 90.0
const TOWN_CENTER := Vector2(0.0, -50.0)
const TOWN_CLEARANCE := 150.0
const FLOOD_DEPTH := 0.6  # water must be this deep for something to spawn on it

var _rng := RandomNumberGenerator.new()
var _wait := 0.0
var _first := true
var _terrain: Terrain


func _ready() -> void:
	_rng.randomize()
	name = "WildlifeManager"


func _physics_process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = SPAWN_EVERY
	var player := get_tree().get_first_node_in_group("player") as Player
	_terrain = get_tree().get_first_node_in_group("terrain") as Terrain
	if player == null or _terrain == null:
		return
	_despawn_far(player)
	for attempt in (FIRST_ATTEMPTS if _first else ATTEMPTS):
		_try_spawn(player, _first)
	_first = false


func _despawn_far(player: Player) -> void:
	for animal: Animal in get_tree().get_nodes_in_group("animals"):
		var gone := animal.global_position.distance_to(player.global_position) > DESPAWN_RADIUS
		if gone and not animal.dead:
			animal.queue_free()


func _try_spawn(player: Player, allow_in_view: bool) -> void:
	var living := _living()
	if living.size() >= MAX_TOTAL:
		return
	var species := _pick_species(living)
	if species == null:
		return
	var spot := _find_spot(species, player, allow_in_view)
	if spot != Vector3.INF:
		_spawn_group(species, spot, living)


func _living() -> Array[Animal]:
	var living: Array[Animal] = []
	for animal: Animal in get_tree().get_nodes_in_group("animals"):
		if not animal.dead:
			living.append(animal)
	return living


## A species chosen by weight among those that have not reached their cap.
func _pick_species(living: Array[Animal]) -> Species:
	var open: Array[Species] = []
	var total := 0.0
	var night := _night()
	for species: Species in SPECIES:
		if _count(species, living) < species.max_alive:
			open.append(species)
			total += _weight(species, night)
	var roll := _rng.randf() * total
	for species in open:
		roll -= _weight(species, night)
		if roll <= 0.0:
			return species
	return null


## How dark it is, 0 to 1; 0 when there is no clock.
func _night() -> float:
	var clock := get_tree().get_first_node_in_group("day_night") as DayNight
	return clock.night if clock != null else 0.0


## Spawn weight with the time of day: day animals thin out at night, night animals come out.
func _weight(species: Species, night: float) -> float:
	match species.activity:
		Species.Activity.DAY:
			return species.spawn_weight * lerpf(1.0, 0.08, night)
		Species.Activity.NIGHT:
			return species.spawn_weight * lerpf(0.25, 1.0, night)
	return species.spawn_weight


func _count(species: Species, living: Array[Animal]) -> int:
	var count := 0
	for animal in living:
		count += 1 if animal.species == species else 0
	return count


# --- where ---------------------------------------------------------------------------------------

## A suitable spot for the species in the ring around the hero, or [constant Vector3.INF].
func _find_spot(species: Species, player: Player, allow_in_view: bool) -> Vector3:
	var angle := _rng.randf() * TAU
	var distance := _rng.randf_range(maxf(RING.x, species.min_player_distance), RING.y)
	var point := player.global_position + Vector3(cos(angle), 0.0, sin(angle)) * distance
	var spot := _spot_for(species, point)
	if spot == Vector3.INF or not _suits(species, spot):
		return Vector3.INF
	if not allow_in_view and _in_view(spot, player):
		return Vector3.INF
	return spot


## Perching species take a spot in a tree near the point; everything else the ground or water.
func _spot_for(species: Species, point: Vector3) -> Vector3:
	if species.behavior == Species.Behavior.PERCH:
		return Perches.pick_near(point, 22.0, _rng)
	if not _terrain.in_bounds(point.x, point.z, 12.0):
		return Vector3.INF
	var on_water := _terrain.is_water(point.x, point.z) and species.water == Species.WaterRule.ON_WATER
	var level := _terrain.water_level_at(point.x, point.z) if on_water else _terrain.height_at(point.x, point.z)
	return Vector3(point.x, level, point.z)


## Whether the terrain around [param spot] is the kind of place the species spawns in.
func _suits(species: Species, spot: Vector3) -> bool:
	var flat := Vector2(spot.x, spot.z)
	var ground := _terrain.height_at(spot.x, spot.z)
	var trees := Perches.count_near(spot, TREE_RADIUS)
	if flat.distance_to(TOWN_CENTER) < TOWN_CLEARANCE or trees < species.trees_min or trees > species.trees_max:
		return false
	if ground < species.min_height or ground > species.max_height:
		return false
	if species.behavior != Species.Behavior.PERCH and _terrain.normal_at(spot.x, spot.z).y < species.min_flatness:
		return false
	return _water_ok(species, spot)


func _water_ok(species: Species, spot: Vector3) -> bool:
	var wet := _terrain.is_water(spot.x, spot.z)
	match species.water:
		Species.WaterRule.AVOID:
			return not wet and not _water_within(spot, 4.0)
		Species.WaterRule.SHORE:
			return not wet and _water_within(spot, 18.0)
		Species.WaterRule.ON_WATER:
			return wet and _terrain.water_level_at(spot.x, spot.z) - _terrain.height_at(spot.x, spot.z) > FLOOD_DEPTH
	return true


## Whether there is water within [param radius] of the point, sampled in a ring.
func _water_within(spot: Vector3, radius: float) -> bool:
	for k in 8:
		var offset := Vector2.from_angle(k * TAU / 8.0) * radius
		if _terrain.is_water(spot.x + offset.x, spot.z + offset.y):
			return true
	return false


func _in_view(spot: Vector3, player: Player) -> bool:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return false
	var offset := spot - camera.global_position
	var looking := -camera.global_basis.z
	return offset.length() < VIEW_DISTANCE and looking.angle_to(offset) < deg_to_rad(VIEW_ANGLE)


# --- spawning ------------------------------------------------------------------------------------

func _spawn_group(species: Species, spot: Vector3, living: Array[Animal]) -> void:
	var room := species.max_alive - _count(species, living)
	var size := mini(_rng.randi_range(species.group_min, species.group_max), room)
	var variant := _rng.randi() % species.models.size()
	var members: Array[Animal] = []
	for k in size:
		var at := spot if k == 0 else _near(species, spot)
		if at != Vector3.INF:
			members.append(_spawn(species, at, variant))
	for member in members:
		if member is PerchedBird:
			(member as PerchedBird).flock.assign(members.filter(func(other: Animal) -> bool: return other is PerchedBird))


## Another spot for the next member of a group, close to the first.
func _near(species: Species, spot: Vector3) -> Vector3:
	for attempt in 6:
		var around := spot + Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0)) * species.group_spread
		var candidate := _spot_for(species, around)
		if candidate != Vector3.INF and _suits(species, candidate):
			return candidate
	return Vector3.INF


func _spawn(species: Species, spot: Vector3, variant: int) -> Animal:
	var animal: Animal
	match species.behavior:
		Species.Behavior.SOAR:
			animal = FlyingPredator.new()
		Species.Behavior.PERCH:
			var bird := PerchedBird.new()
			bird.perch = spot
			animal = bird
		_:
			animal = GroundAnimal.new()
	animal.species = species
	animal.variant = variant
	animal.position = spot + Vector3.UP * (0.0 if species.behavior == Species.Behavior.PERCH else 0.3)
	add_child(animal)
	return animal
