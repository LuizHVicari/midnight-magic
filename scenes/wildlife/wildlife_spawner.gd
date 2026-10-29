class_name WildlifeSpawner
extends Feature
## Fills the map with animals once the ground is final. Each species is placed in the kind of
## terrain it likes: groups of rabbits on dry, gentle ground away from the town, eagles with a
## home high over the land. A few are always placed near where the hero starts, to try things
## on. Animals freeze and hide when the hero is far away (see [Animal]), so a big count is cheap.

const RABBIT := preload("res://scenes/wildlife/species/rabbit.tres")
const EAGLE := preload("res://scenes/wildlife/species/eagle.tres")

const TOWN_CENTER := Vector2(0.0, -50.0)
const TOWN_CLEARANCE := 160.0
const START := Vector2(0.0, 430.0)

@export var rabbit_groups := 40
@export var eagles := 4


func _init() -> void:
	priority = 200


func populate(_scatter: Scatter) -> void:
	seed_rng(11)
	_demo_animals()
	for k in rabbit_groups:
		var spot := _random_land()
		for r in rng.randi_range(1, 3):
			_spawn(RABBIT, spot + Vector2(rng.randf_range(-6.0, 6.0), rng.randf_range(-6.0, 6.0)))
	for k in eagles:
		_spawn(EAGLE, _random_land(), rng.randf_range(20.0, 35.0))


## A few close to the start: rabbits to chase and an eagle circling north of the road.
func _demo_animals() -> void:
	for offset in [Vector2(12, -18), Vector2(-10, -26), Vector2(18, -34)]:
		_spawn(RABBIT, START + offset)
	_spawn(EAGLE, START + Vector2(-20.0, -75.0), 24.0)


func _spawn(species: Species, spot: Vector2, height := 0.0) -> void:
	var animal := _make(species)
	animal.position = Vector3(spot.x, terrain.height_at(spot.x, spot.y) + height + 0.3, spot.y)
	add_child(animal)


func _make(species: Species) -> Animal:
	var animal: Animal = FlyingPredator.new() if species.cruise_height > 0.0 else GroundAnimal.new()
	animal.species = species
	return animal


## A random dry, gentle spot in the playable area, away from the town.
func _random_land() -> Vector2:
	for attempt in 40:
		var spot := Vector2(rng.randf_range(-480.0, 480.0), rng.randf_range(-480.0, 480.0))
		var usable := not terrain.is_water(spot.x, spot.y) and terrain.normal_at(spot.x, spot.y).y > 0.9
		if usable and spot.distance_to(TOWN_CENTER) > TOWN_CLEARANCE:
			return spot
	return START
