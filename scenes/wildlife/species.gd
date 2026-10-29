class_name Species
extends Resource
## Everything that makes one kind of animal different from another. The behavior code is shared
## by every species of the same family ([GroundAnimal], [FlyingPredator]); a species only brings
## numbers, a model and a loot table.

enum Temperament {
	PASSIVE,  ## ignores the hero, only runs once hurt
	SKITTISH,  ## runs from the hero as soon as it sees or hears them
	AGGRESSIVE,  ## hunts the hero
}

enum Activity { DAY, NIGHT, ANY }

## Which family of behavior drives the species: [GroundAnimal], [FlyingPredator] or [PerchedBird].
enum Behavior { GROUND, SOAR, PERCH }

## Where it may spawn relative to water.
enum WaterRule { AVOID, SHORE, ON_WATER, ANY }

@export var display_name := ""
## One of these is picked for every animal of the species.
@export var models: Array[PackedScene] = []
## Size of the model in the world, on top of its own scale.
@export var model_scale := 1.0
@export var behavior := Behavior.GROUND
@export var temperament := Temperament.SKITTISH
@export var activity := Activity.ANY
@export var max_health := 20.0

@export_group("Movement")
@export var walk_speed := 1.6
@export var run_speed := 6.0
@export var turn_speed := 8.0
## Wanders within this distance of where it was born.
@export var home_radius := 25.0
## Flying species cruise this far above the ground.
@export var cruise_height := 0.0
## Can float on water (ducks): it rides on the surface instead of walking on the bed.
@export var swims := false
@export var float_depth := 0.1

@export_group("Senses")
@export var sight_range := 18.0
## Full width of the cone the animal sees in, in degrees.
@export var sight_angle := 150.0
## How far it hears the hero at normal walking noise; sprinting and spells are louder.
@export var hearing_range := 9.0
## Keeps running until at least this far from what scared it.
@export var safe_distance := 24.0
## Perched species take off when the hero gets closer than this (louder hero, farther).
@export var flee_distance := 12.0

@export_group("Body")
@export var body_radius := 0.3
@export var body_height := 0.6

@export_group("Attack")
@export var attack_damage := 0.0
@export var attack_range := 2.0
@export var attack_cooldown := 6.0
@export var attack_push := 7.0

@export_group("Animations")
## Role (idle, walk, run, eat, sleep...) to the end of an animation's name in the model. The
## models name them like "Rig|Rig|Rabbit_idle", so "Rabbit_idle" is enough.
@export var animations: Dictionary = {}

@export_group("Spawning")
## Relative chance of being picked on a spawn attempt, like in Minecraft.
@export var spawn_weight := 1.0
## No more than this many alive at once.
@export var max_alive := 6
## A spawn brings a group of this size; birds in a flock, a lone fox.
@export var group_min := 1
@export var group_max := 1
@export var group_spread := 6.0
@export var min_player_distance := 35.0
@export var water := WaterRule.AVOID
@export var min_height := -1000.0
@export var max_height := 1000.0
## Smallest upward component of the ground's normal: 1 is flat, lower allows slopes.
@export var min_flatness := 0.85
## Trees within 30 m: few for meadows, many for forests.
@export var trees_min := 0
@export var trees_max := 99999

@export_group("Loot")
@export var loot: Array[LootEntry] = []


func random_model(rng: RandomNumberGenerator) -> PackedScene:
	return models[rng.randi() % models.size()]
