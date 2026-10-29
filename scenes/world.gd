extends Node3D
## Builds the whole map. Terrain first, then every Feature (lakes, town, roads, rivers,
## clearings, vegetation) shapes the ground in priority order and, once heights are final,
## places its props. To grow the map, add more features to [_layout].
##
## North is -z. The player starts in the south, follows the road over a river, past a camp,
## through the gate of the walled town; lakes, creeks, ruins and standing stones lie beyond.

const SEED := 20261027
const SPAWN := Vector2(0.0, 430.0)
const TOWN_CENTER := Vector2(0.0, -50.0)


func _ready() -> void:
	var terrain := Terrain.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.generate_base(SEED)

	var features := _layout()
	features.sort_custom(func(a: Feature, b: Feature) -> bool: return a.priority < b.priority)
	for feature in features:
		feature.terrain = terrain
		add_child(feature)
	for feature in features:
		feature.shape()
	terrain.finalize()

	var scatter := Scatter.new()
	scatter.name = "Scatter"
	scatter.terrain = terrain
	add_child(scatter)
	for feature in features:
		feature.populate(scatter)
	scatter.flush()

	_build_boundaries()
	_spawn_player(terrain)
	_place_training_dummies(terrain)


func _layout() -> Array[Feature]:
	var town := Town.create(TOWN_CENTER)
	var gate := town.gate_point()
	var big_lake := Lake.create(Vector2(300, 150), 75.0, 2.6)
	var tarn := Lake.create(Vector2(-265, -170), 42.0, 2.0)

	var features: Array[Feature] = [town, big_lake, tarn, Vegetation.new()]

	# Water: a river across the road to the big lake, a creek down to the tarn.
	features.append(River.create(_pts([
		-470, 100, -390, 150, -300, 215, -200, 240, -100, 222, 0, 238, 100, 255, 190, 225, 250, 185,
	]), 6.0, 1.4, big_lake))
	features.append(River.create(_pts([
		-130, -445, -175, -380, -215, -300, -240, -230, -250, -190,
	]), 2.6, 0.9, tarn))

	# Roads: spawn -> bridge -> gate, with branches to the lake and the tarn.
	features.append(Road.create(_pts([
		SPAWN.x, SPAWN.y, 12, 385, -14, 335, -4, 290, 0, 250, 0, 215, 8, 175,
		gate.x, gate.y + 60, gate.x, gate.y + 30, gate.x, gate.y,
	]), 5.5))
	features.append(Road.create(_pts([8, 158, 70, 140, 130, 105, 185, 100, 195, 118]), 4.0))
	features.append(Road.create(_pts([-6, 128, -70, 100, -135, 55, -185, -20, -205, -90]), 4.0))

	# Clearings: the same component, different kinds and places.
	var clearings := [
		[Clearing.Kind.MEADOW, 0, 425, 26],
		[Clearing.Kind.CAMP, -40, 330, 24],
		[Clearing.Kind.MEADOW, 130, 320, 30],
		[Clearing.Kind.MEADOW, -180, 330, 28],
		[Clearing.Kind.MEADOW, -330, 380, 24],
		[Clearing.Kind.MEADOW, 330, 330, 26],
		[Clearing.Kind.RUINS, -300, 60, 28],
		[Clearing.Kind.RUINS, 150, -250, 30],
		[Clearing.Kind.STONES, -130, -230, 26],
		[Clearing.Kind.STONES, 190, -120, 26],
		[Clearing.Kind.CAMP, 230, -190, 24],
		[Clearing.Kind.MEADOW, 60, -350, 28],
		[Clearing.Kind.MEADOW, -90, -370, 26],
		[Clearing.Kind.MEADOW, 300, -330, 28],
		[Clearing.Kind.MEADOW, -380, -250, 26],
	]
	for c in clearings:
		features.append(Clearing.create(c[0], Vector2(c[1], c[2]), c[3]))
	return features


## Flat list of x, z pairs to a polyline.
func _pts(coords: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(0, coords.size(), 2):
		points.append(Vector2(coords[i], coords[i + 1]))
	return points


func _build_boundaries() -> void:
	var half := Terrain.HALF
	Kit.add_block(self, Vector3(0, -30, 0), Vector3(Terrain.SIZE, 2, Terrain.SIZE))
	Kit.add_block(self, Vector3(0, 40, -half - 1), Vector3(Terrain.SIZE + 2, 200, 2))
	Kit.add_block(self, Vector3(0, 40, half + 1), Vector3(Terrain.SIZE + 2, 200, 2))
	Kit.add_block(self, Vector3(-half - 1, 40, 0), Vector3(2, 200, Terrain.SIZE))
	Kit.add_block(self, Vector3(half + 1, 40, 0), Vector3(2, 200, Terrain.SIZE))


func _spawn_player(terrain: Terrain) -> void:
	var player := get_parent().get_node_or_null("Player") as Node3D
	if player == null:
		return
	player.global_position = Vector3(SPAWN.x, terrain.height_at(SPAWN.x, SPAWN.y) + 1.0, SPAWN.y)


## Targets just ahead of the spawn point, to try spells on until there are real enemies.
func _place_training_dummies(terrain: Terrain) -> void:
	for offset in [Vector2(3.0, -12.0), Vector2(-4.0, -17.0), Vector2(2.0, -23.0)]:
		var at: Vector2 = SPAWN + offset
		var dummy := TrainingDummy.new()
		add_child(dummy)
		dummy.global_position = Vector3(at.x, terrain.height_at(at.x, at.y), at.y)
