extends Node3D
## Builds the map from Kenney kits on a grid of Kit.CELL meters. The player starts in
## the south; the path crosses a stream, passes a camp and reaches the walled town.
## Rows grow southwards, so row 0 is the far north edge of the map.

const COLS := 19
const ROWS := 64
const ROAD_COL := 9
const SPAWN_ROW := 61
const ROW_STREAM := 56

const TOWN_N := 2
const TOWN_S := 27  # gate row
const TOWN_W := 2
const TOWN_E := 16

# Kenney path and river tiles have their flat margin 0.05 units below the grass tile, and
# the town road tile stands 0.026 units above it. Shift them so every surface meets the
# grass at the same height, otherwise a vertical wall shows at the seam.
const NATURE_TILE_LIFT := 0.05 * 5.0
const ROAD_TILE_DROP := 0.026 * 5.0

# The bridge deck sits above the ground so it never shares a plane with the water.
const BRIDGE_DECK_HEIGHT := 0.3

const CAMP_COL := 4.0
const CAMP_ROW := 44.0

const TREES := [
	"tree_default", "tree_oak", "tree_detailed", "tree_fat", "tree_pineDefaultA",
	"tree_pineDefaultB", "tree_pineTallA", "tree_pineTallB", "tree_pineRoundA",
]
const SMALL_PLANTS := [
	"plant_bush", "plant_bushLarge", "plant_bushSmall", "grass_large", "grass",
	"flower_redA", "flower_yellowA", "flower_purpleA", "flower_redB", "mushroom_redGroup",
	"rock_smallA", "rock_smallB", "stone_largeA", "log",
]

# [col, row, width, depth, door side, floors, wood walls, roof]; col/row is the NW cell.
const HOUSES := [
	# Town hall at the end of the main street, flanked by two houses on each side.
	[7, 3, 5, 4, "S", 2, false, Building.Roof.HIGH],
	[3, 3, 3, 2, "E", 1, true, Building.Roof.GABLE],
	[3, 5, 3, 2, "E", 2, false, Building.Roof.HIGH],
	[13, 3, 3, 2, "W", 2, false, Building.Roof.HIGH],
	[13, 5, 3, 2, "W", 1, true, Building.Roof.GABLE],
	# North of the plaza.
	[5, 8, 3, 2, "E", 2, false, Building.Roof.HIGH],
	[5, 10, 3, 2, "E", 1, true, Building.Roof.GABLE],
	[11, 8, 3, 2, "W", 1, true, Building.Roof.GABLE],
	[11, 10, 3, 2, "W", 2, false, Building.Roof.HIGH],
	# Along the cross street.
	[3, 12, 3, 2, "S", 1, false, Building.Roof.GABLE],
	[3, 15, 3, 2, "N", 2, true, Building.Roof.HIGH],
	[13, 12, 3, 2, "S", 2, true, Building.Roof.HIGH],
	[13, 15, 3, 2, "N", 1, false, Building.Roof.GABLE],
	# South of the plaza, down to the gate.
	[5, 17, 3, 2, "E", 1, true, Building.Roof.GABLE],
	[5, 19, 3, 2, "E", 2, false, Building.Roof.HIGH],
	[5, 21, 3, 2, "E", 1, false, Building.Roof.GABLE],
	[5, 23, 3, 2, "E", 2, true, Building.Roof.HIGH],
	[5, 25, 3, 2, "E", 1, true, Building.Roof.GABLE],
	[11, 17, 3, 2, "W", 2, false, Building.Roof.HIGH],
	[11, 19, 3, 2, "W", 1, true, Building.Roof.GABLE],
	[11, 21, 3, 2, "W", 2, true, Building.Roof.HIGH],
	[11, 23, 3, 2, "W", 1, false, Building.Roof.GABLE],
	[11, 25, 3, 2, "W", 2, false, Building.Roof.HIGH],
]

var _rng := RandomNumberGenerator.new()
var _paved := {}  # Vector2i cells covered by road, path or stream tiles


func _ready() -> void:
	_rng.seed = 20261027
	_mark_paved()
	_build_ground()
	_build_boundaries()
	_build_roads()
	_build_stream()
	_build_town_wall()
	for spec in HOUSES:
		Building.build(self, _cell_pos(spec[0], spec[1]), spec[2], spec[3], spec[4], spec[5], spec[6], spec[7])
	_build_plaza()
	_build_street_props()
	_build_town_gardens()
	_build_camp()
	_scatter_nature()


func _cell_pos(col: float, row: float) -> Vector3:
	return Kit.cell_pos(col, row, ROAD_COL, SPAWN_ROW)


func _place(pack: String, model: String, pos: Vector3, yaw := 0.0, collision := Kit.Collision.AUTO, scale_mult := 1.0) -> Node3D:
	return Kit.place(self, pack, model, pos, yaw, collision, scale_mult)


func _in_town(col: float, row: float) -> bool:
	return col >= TOWN_W and col <= TOWN_E and row >= TOWN_N and row <= TOWN_S


func _in_camp(col: int, row: int) -> bool:
	return col >= 0 and col <= 7 and row >= 38 and row <= 50


func _jitter(col: float, row: float) -> Vector3:
	var half := Kit.CELL * 0.4
	return _cell_pos(col, row) + Vector3(_rng.randf_range(-half, half), 0.0, _rng.randf_range(-half, half))


# --- ground -------------------------------------------------------------------

func _mark_paved() -> void:
	for row in range(7, ROWS - 1):
		_paved[Vector2i(ROAD_COL, row)] = true
	for col in range(TOWN_W + 1, TOWN_E):
		_paved[Vector2i(col, 14)] = true
	for row in range(12, 17):
		for col in range(7, 12):
			_paved[Vector2i(col, row)] = true
	for col in COLS:
		_paved[Vector2i(col, ROW_STREAM)] = true


func _build_ground() -> void:
	# Safety floor far below the surface, in case something slips through a seam.
	var center_z := _cell_pos(0, (ROWS - 1) * 0.5).z
	Kit.add_block(self, Vector3(0, -1.5, center_z), Vector3(COLS * Kit.CELL, 1.0, ROWS * Kit.CELL))

	# Each run of grass cells in a row is one textured strip plus one flat collision box.
	# Paved cells (path, road, stream) are sunken or raised, so they use their own mesh.
	var material := _grass_material()
	for row in ROWS:
		var run_start := -1
		for col in COLS + 1:
			var grass := col < COLS and not _paved.has(Vector2i(col, row))
			if grass:
				if run_start < 0:
					run_start = col
			elif run_start >= 0:
				_add_grass_strip(run_start, col - run_start, row, material)
				run_start = -1


func _grass_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/shaders/grass_ground.gdshader")
	material.set_shader_parameter("patches", load("res://assets/textures/patterns/pattern37.png"))
	material.set_shader_parameter("tufts", load("res://assets/textures/patterns/pattern56.png"))
	return material


func _add_grass_strip(first_col: int, cells: int, row: int, material: Material) -> void:
	var mid := _cell_pos(first_col + (cells - 1) * 0.5, row)
	var plane := PlaneMesh.new()
	plane.size = Vector2(cells * Kit.CELL, Kit.CELL)
	var strip := MeshInstance3D.new()
	strip.mesh = plane
	strip.material_override = material
	strip.position = mid
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(strip)
	Kit.add_block(self, mid + Vector3(0, -0.5, 0), Vector3(cells * Kit.CELL, 1.0, Kit.CELL))


func _build_boundaries() -> void:
	var w := COLS * Kit.CELL
	var l := ROWS * Kit.CELL
	var cz := _cell_pos(0, (ROWS - 1) * 0.5).z
	Kit.add_block(self, Vector3(0, 8, cz - l * 0.5 - 1), Vector3(w + 2, 16, 2))
	Kit.add_block(self, Vector3(0, 8, cz + l * 0.5 + 1), Vector3(w + 2, 16, 2))
	Kit.add_block(self, Vector3(-w * 0.5 - 1, 8, cz), Vector3(2, 16, l))
	Kit.add_block(self, Vector3(w * 0.5 + 1, 8, cz), Vector3(2, 16, l))


func _build_roads() -> void:
	for cell in _paved:
		if cell.y == ROW_STREAM:
			continue
		if cell.y > TOWN_S:
			_place("nature", "ground_pathStraight", _cell_pos(cell.x, cell.y) + Vector3(0, NATURE_TILE_LIFT, 0), 0.0, Kit.Collision.MESH)
		else:
			_place("town", "road", _cell_pos(cell.x, cell.y) - Vector3(0, ROAD_TILE_DROP, 0), 0.0, Kit.Collision.MESH)


func _build_stream() -> void:
	for col in COLS:
		_place("nature", "ground_riverStraight", _cell_pos(col, ROW_STREAM) + Vector3(0, NATURE_TILE_LIFT, 0), 90.0, Kit.Collision.MESH)
	# The deck sits 0.15 * scale above the model origin; offset so it ends up BRIDGE_DECK_HEIGHT above ground.
	var offset := BRIDGE_DECK_HEIGHT - 0.15 * Kit.PACK_SCALE["nature"]
	_place("nature", "bridge_wood", _cell_pos(ROAD_COL, ROW_STREAM) + Vector3(0, offset, 0), 90.0, Kit.Collision.MESH)


# --- town ---------------------------------------------------------------------

func _build_town_wall() -> void:
	for col in range(TOWN_W, TOWN_E + 1):
		_place("town", "wall", _cell_pos(col, TOWN_N), 90.0, Kit.Collision.MESH)
		if col == ROAD_COL:
			_place("town", "wall-arch", _cell_pos(col, TOWN_S), -90.0, Kit.Collision.MESH)
		else:
			_place("town", "wall", _cell_pos(col, TOWN_S), -90.0, Kit.Collision.MESH)
	for row in range(TOWN_N, TOWN_S + 1):
		_place("town", "wall", _cell_pos(TOWN_W, row), 180.0, Kit.Collision.MESH)
		_place("town", "wall", _cell_pos(TOWN_E, row), 0.0, Kit.Collision.MESH)

	for corner in [Vector2(TOWN_W, TOWN_N), Vector2(TOWN_E, TOWN_N), Vector2(TOWN_W, TOWN_S), Vector2(TOWN_E, TOWN_S)]:
		_place("town", "pillar-stone", _cell_pos(corner.x, corner.y), 0.0, Kit.Collision.MESH)
	for side in [-1, 1]:
		var p := _cell_pos(ROAD_COL + side * 1.0, TOWN_S)
		_place("town", "lantern", p + Vector3(side * 1.4, 0, 1.5), 0.0, Kit.Collision.MESH)
		_place("town", "banner-red", p + Vector3(side * -0.9, 0, 2.4))


func _build_plaza() -> void:
	_place("town", "fountain-round", _cell_pos(ROAD_COL, 14), 0.0, Kit.Collision.MESH)
	_place("town", "stall-red", _cell_pos(7.7, 12.4), 0.0, Kit.Collision.MESH)
	_place("town", "stall-green", _cell_pos(10.3, 12.4), 0.0, Kit.Collision.MESH)
	_place("town", "stall-green", _cell_pos(7.7, 15.6), 180.0, Kit.Collision.MESH)
	_place("town", "stall-red", _cell_pos(10.3, 15.6), 180.0, Kit.Collision.MESH)
	_place("town", "stall-bench", _cell_pos(8.2, 16.4), 180.0)
	_place("town", "stall-bench", _cell_pos(9.8, 12.0), 0.0)
	_place("town", "cart", _cell_pos(7.3, 14.9), 90.0, Kit.Collision.MESH)
	_place("town", "stall-stool", _cell_pos(8.0, 13.3), 20.0)
	for corner in [Vector2(6.3, 12.7), Vector2(11.7, 12.7), Vector2(6.3, 15.3), Vector2(11.7, 15.3)]:
		_place("town", "tree", _cell_pos(corner.x, corner.y), _rng.randf() * 360.0, Kit.Collision.TRUNK, 0.5)
	_place("town", "banner-green", _cell_pos(7.0, 7.1))
	_place("town", "banner-green", _cell_pos(11.0, 7.1))
	_place("town", "windmill", _cell_pos(14.6, 9.4), 200.0, Kit.Collision.MESH)


func _build_street_props() -> void:
	for row in [8, 11, 18, 21, 24]:
		for side in [-1, 1]:
			_place("town", "lantern", _cell_pos(ROAD_COL + side * 0.62, row + 0.5), 0.0, Kit.Collision.MESH)
	for col in [4, 6, 12, 14]:
		_place("town", "lantern", _cell_pos(col, 13.55), 0.0, Kit.Collision.MESH)
		_place("town", "lantern", _cell_pos(col, 14.45), 0.0, Kit.Collision.MESH)


func _build_town_gardens() -> void:
	# Yards between the houses and the wall: hedges, trees and the odd cart.
	for row in range(17, 27):
		_place("town", "hedge-large", _cell_pos(3.4, row), 90.0, Kit.Collision.MESH)
		_place("town", "hedge-large", _cell_pos(15.6, row), 90.0, Kit.Collision.MESH)
	for row in [18.5, 21.5, 24.5]:
		_place("town", "tree", _cell_pos(3.4, row), _rng.randf() * 360.0, Kit.Collision.TRUNK, 0.55)
		_place("town", "tree", _cell_pos(15.6, row), _rng.randf() * 360.0, Kit.Collision.TRUNK, 0.55)
	for row in [9.5, 10.5]:
		_place("town", "tree", _cell_pos(3.5, row), _rng.randf() * 360.0, Kit.Collision.TRUNK, 0.6)
	_place("town", "cart", _cell_pos(4.2, 20.2), 70.0, Kit.Collision.MESH)
	_place("town", "stall-red", _cell_pos(14.4, 20.0), -90.0, Kit.Collision.MESH)


# --- camp ---------------------------------------------------------------------

func _build_camp() -> void:
	var fire := _cell_pos(CAMP_COL, CAMP_ROW)
	_place("survival", "campfire-pit", fire, 0.0, Kit.Collision.MESH)
	_place("nature", "log", fire + Vector3(5.0, 0, 1.8), 80.0, Kit.Collision.MESH)
	_place("nature", "log", fire + Vector3(-5.0, 0, -1.5), 100.0, Kit.Collision.MESH)
	_place("nature", "log", fire + Vector3(0.5, 0, 5.5), 10.0, Kit.Collision.MESH)
	_place("survival", "tent", fire + Vector3(-9.0, 0, 9.5), 150.0, Kit.Collision.MESH)
	_place("survival", "tent", fire + Vector3(9.5, 0, 9.0), 215.0, Kit.Collision.MESH)
	_place("survival", "tent-canvas", fire + Vector3(0.5, 0, -12.5), 0.0, Kit.Collision.MESH)
	_place("survival", "bedroll", fire + Vector3(-3.5, 0, 5.0), 30.0)
	_place("survival", "barrel", fire + Vector3(-12.0, 0, -3.5), 0.0, Kit.Collision.MESH)
	_place("survival", "box", fire + Vector3(-11.2, 0, -7.0), 20.0, Kit.Collision.MESH)
	_place("survival", "box-large", fire + Vector3(-13.0, 0, -9.0), 50.0, Kit.Collision.MESH)
	_place("survival", "chest", fire + Vector3(11.5, 0, -6.5), -30.0, Kit.Collision.MESH)
	_place("survival", "workbench", fire + Vector3(12.5, 0, 0.0), -90.0, Kit.Collision.MESH)
	_place("survival", "signpost", _cell_pos(ROAD_COL - 1.0, CAMP_ROW + 1.0), 20.0, Kit.Collision.MESH)
	_place("survival", "signpost", _cell_pos(ROAD_COL + 1.0, TOWN_S + 3.0), 190.0, Kit.Collision.MESH)

	# Ring of trees around the clearing, left open towards the path.
	for step in 11:
		var angle := step * TAU / 11.0
		if cos(angle) > 0.55:
			continue
		var radius := _rng.randf_range(21.0, 26.0)
		var pos := fire + Vector3(cos(angle), 0, sin(angle)) * radius
		var model: String = TREES[_rng.randi() % TREES.size()]
		_place("nature", model, pos, _rng.randf() * 360.0, Kit.Collision.TRUNK, _rng.randf_range(0.9, 1.3))


# --- vegetation ---------------------------------------------------------------

func _scatter_nature() -> void:
	for row in range(0, ROWS - 1):
		for col in COLS:
			if _in_town(col, row) or _in_camp(col, row) or row == ROW_STREAM:
				continue
			if abs(col - ROAD_COL) < 2 and row > TOWN_S:
				continue
			var edge := col <= 2 or col >= COLS - 3 or row <= 1
			if _rng.randf() < (0.85 if edge else 0.34):
				var model: String = TREES[_rng.randi() % TREES.size()]
				_place("nature", model, _jitter(col, row), _rng.randf() * 360.0, Kit.Collision.TRUNK, _rng.randf_range(0.85, 1.25))
			if _rng.randf() < 0.85:
				var small: String = SMALL_PLANTS[_rng.randi() % SMALL_PLANTS.size()]
				_place("nature", small, _jitter(col, row), _rng.randf() * 360.0, Kit.Collision.AUTO, _rng.randf_range(0.8, 1.3))

	# Flowers lining the path in the starting meadow.
	for row in range(ROW_STREAM + 1, ROWS - 1):
		for side in [-1, 1]:
			var model: String = SMALL_PLANTS[_rng.randi() % SMALL_PLANTS.size()]
			_place("nature", model, _jitter(ROAD_COL + side * 1.25, row), _rng.randf() * 360.0)
