class_name LootEntry
extends Resource
## One possible drop of a [Species]: an item name, how likely it is and how many.

@export var item := ""
@export_range(0.0, 1.0) var chance := 1.0
@export var min_count := 1
@export var max_count := 1


## How many of this item to drop this time; 0 if the roll fails.
func roll(rng: RandomNumberGenerator) -> int:
	if rng.randf() > chance:
		return 0
	return rng.randi_range(min_count, max_count)
