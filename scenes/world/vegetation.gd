class_name Vegetation
extends Feature
## Fills everything the other features left free: forests that thin out into meadows,
## deciduous trees in the lowlands and pines on the heights, grass, bushes, flowers, boulders
## on steep ground and pebbles along the water. Runs last.

const LOW_TREES := [
	"tree_default", "tree_oak", "tree_detailed", "tree_fat", "tree_simple", "tree_tall", "tree_thin",
]
const AUTUMN_TREES := ["tree_default_fall", "tree_oak_fall", "tree_detailed_fall"]
const MID_TREES := [
	"tree_pineDefaultA", "tree_pineDefaultB", "tree_pineRoundA", "tree_pineRoundB", "tree_pineRoundC",
	"tree_pineRoundD",
]
const HIGH_TREES := [
	"tree_pineTallA", "tree_pineTallB", "tree_pineTallC", "tree_pineTallD", "tree_cone", "tree_cone_dark",
]
const GRASS := ["grass", "grass_large", "grass_leafs", "grass_leafsLarge", "plant_flatShort", "plant_flatTall"]
const BUSHES := ["plant_bush", "plant_bushLarge", "plant_bushSmall", "plant_bushDetailed", "plant_bushTriangle"]
const FLOWERS := [
	"flower_redA", "flower_redB", "flower_redC", "flower_yellowA", "flower_yellowB", "flower_yellowC",
	"flower_purpleA", "flower_purpleB", "flower_purpleC",
]
const MUSHROOMS := ["mushroom_redGroup", "mushroom_tanGroup", "mushroom_red", "mushroom_tan"]
const PEBBLES := ["rock_smallA", "rock_smallB", "rock_smallC", "rock_smallD", "stone_smallA", "stone_smallB"]
const BOULDERS := [
	"rock_largeA", "rock_largeB", "rock_largeC", "rock_largeD", "stone_largeA", "stone_largeB",
	"rock_tallA", "rock_tallB", "stone_tallA", "stone_tallB",
]

const TREE_SPACING := 6.0
const PLANT_SPACING := 4.5

var _forest := FastNoiseLite.new()
var _meadow := FastNoiseLite.new()


func _init() -> void:
	priority = 100
	_forest.frequency = 0.004
	_forest.fractal_octaves = 3
	_meadow.frequency = 0.03


## Tree model suited to the altitude, with a little mixing between the bands.
static func tree_model(random: RandomNumberGenerator, altitude: float) -> String:
	var band := clampf((altitude - 12.0) / 40.0 + random.randf_range(-0.25, 0.25), 0.0, 1.0)
	if band < 0.3:
		var pool: Array = AUTUMN_TREES if random.randf() < 0.03 else LOW_TREES
		return pool[random.randi() % pool.size()]
	var pines: Array = MID_TREES if band < 0.65 else HIGH_TREES
	return pines[random.randi() % pines.size()]


func populate(scatter: Scatter) -> void:
	seed_rng(3)
	_forest.seed = rng.seed
	_meadow.seed = rng.seed + 1
	_scatter_trees(scatter)
	_scatter_ground_cover(scatter)


func _grid_jitter(index: int, spacing: float) -> float:
	return -Terrain.HALF + (index + rng.randf()) * spacing


func _scatter_trees(scatter: Scatter) -> void:
	var count := int(Terrain.SIZE / TREE_SPACING)
	for iz in count:
		for ix in count:
			var x := _grid_jitter(ix, TREE_SPACING)
			var z := _grid_jitter(iz, TREE_SPACING)
			var i := terrain.index_at(x, z)
			if (terrain.keep_clear[i] & Terrain.CLEAR_TREES) != 0 or terrain.wet[i] > 0.02:
				continue
			var forest := smoothstep(-0.1, 0.3, _forest.get_noise_2d(x, z))
			if rng.randf() > forest * 0.85 + 0.03:
				continue
			if terrain.normal_at(x, z).y < 0.78:
				continue
			var h := terrain.heights[i]
			scatter.add(
				"nature", tree_model(rng, h), Vector3(x, h, z), rng.randf() * TAU, rng.randf_range(0.85, 1.35),
				Scatter.Solid.TRUNK, 420.0, true,
			)


func _scatter_ground_cover(scatter: Scatter) -> void:
	var count := int(Terrain.SIZE / PLANT_SPACING)
	for iz in count:
		for ix in count:
			var x := _grid_jitter(ix, PLANT_SPACING)
			var z := _grid_jitter(iz, PLANT_SPACING)
			var i := terrain.index_at(x, z)
			if (terrain.keep_clear[i] & Terrain.CLEAR_ALL) == Terrain.CLEAR_ALL:
				continue
			_ground_cover_at(scatter, i, x, z)


func _shore_cover(scatter: Scatter, pos: Vector3, yaw: float, roll: float) -> void:
	if roll > 0.18:
		return
	var model: String = PEBBLES[rng.randi() % PEBBLES.size()]
	scatter.add("nature", model, pos, yaw, rng.randf_range(0.8, 1.5), Scatter.Solid.NONE, 160.0)


func _steep_cover(scatter: Scatter, pos: Vector3, yaw: float, roll: float) -> void:
	if roll > 0.12:
		return
	var model: String = BOULDERS[rng.randi() % BOULDERS.size()]
	scatter.add("nature", model, pos, yaw, rng.randf_range(1.0, 2.0), Scatter.Solid.ROCK, 300.0, true)


func _ground_cover_at(scatter: Scatter, i: int, x: float, z: float) -> void:
	var h := terrain.heights[i]
	var pos := Vector3(x, h, z)
	var yaw := rng.randf() * TAU
	var roll := rng.randf()
	if terrain.wet[i] > 0.05:
		_shore_cover(scatter, pos, yaw, roll)
		return
	if terrain.normal_at(x, z).y < 0.8:
		_steep_cover(scatter, pos, yaw, roll)
		return
	var patch := _meadow.get_noise_2d(x, z)
	var pool := GRASS
	if patch > 0.35:
		pool = FLOWERS
	elif patch < -0.4:
		pool = BUSHES
	elif roll < 0.03:
		pool = MUSHROOMS
	elif roll < 0.05:
		pool = BOULDERS
	var chance := 0.55 if pool != BOULDERS else 1.0
	if rng.randf() > chance:
		return
	var model: String = pool[rng.randi() % pool.size()]
	var solid := Scatter.Solid.ROCK if pool == BOULDERS else Scatter.Solid.NONE
	scatter.add("nature", model, pos, yaw, rng.randf_range(0.8, 1.4), solid, 120.0 if pool != BOULDERS else 300.0)
