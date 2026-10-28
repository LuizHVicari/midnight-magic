class_name Town
extends Feature
## Walled town that grows organically on a gentle plateau: curved cobbled streets lined with
## houses at slightly different angles and heights (each house levels its own pad of ground),
## a big central plaza with fountain, market stalls and town hall, an irregular wall and a
## south gate that lines up exactly with the approach road ([gate_point]).

const WALL_STEP := 5.0
const GATE_HALF := 3.2
const TOWER := 5.0
const GATE_CLEAR := GATE_HALF + TOWER + 2.5

@export var radius := 125.0
@export var plaza_radius := 28.0

var _roads: Array[Road] = []
var _road_boxes: Array[Rect2] = []
var _houses: Array[Dictionary] = []
var _wall_noise := FastNoiseLite.new()
var _plateau := 0.0

## Streets relative to the town center for a 105 m radius, scaled with [radius]: [width, points].
## South is +z.
const STREETS := [
	[7.0, [Vector2(0, 112), Vector2(0, 80), Vector2(0, 50), Vector2(0, 26)]],
	[6.0, [Vector2(-25, -4), Vector2(-56, -26), Vector2(-84, 4), Vector2(-78, 44), Vector2(-45, 68), Vector2(0, 72)]],
	[6.0, [Vector2(25, -6), Vector2(58, -28), Vector2(86, 2), Vector2(74, 42), Vector2(40, 66), Vector2(0, 72)]],
	[4.5, [Vector2(-56, -26), Vector2(-72, -56), Vector2(-52, -84)]],
	[4.5, [Vector2(58, -28), Vector2(70, -58), Vector2(50, -86)]],
]


static func create(at: Vector2, town_radius := 125.0) -> Town:
	var town := Town.new()
	town.position = Vector3(at.x, 0.0, at.y)
	town.radius = town_radius
	return town


func _init() -> void:
	priority = 20
	_wall_noise.seed = 77
	_wall_noise.frequency = 1.0


## Wall radius towards [angle]: irregular so the outline never looks like a compass drawing.
func wall_radius(angle: float) -> float:
	return radius * (1.0 + 0.16 * _wall_noise.get_noise_2d(cos(angle) * 1.5, sin(angle) * 1.5))


## World (x, z) of the gate in the south wall; the approach road must end here.
func gate_point() -> Vector2:
	return center() + Vector2(0.0, wall_radius(PI * 0.5))


# --- shaping ------------------------------------------------------------------

func shape() -> void:
	_plateau = _mean_height()
	terrain.for_cells_in_disc(center(), radius * 1.45, _level_ground)
	terrain.for_cells_in_disc(center(), plaza_radius + 10.0, _flatten_plaza)
	_make_streets()
	_plan_houses()
	for house in _houses:
		_level_pad(house)
	for road in _roads:
		road.shape()


func _mean_height() -> float:
	var sum := 0.0
	var count := 0
	for ring: float in [0.0, 0.4, 0.8]:
		for k in (1 if ring == 0.0 else 8):
			var p := center() + Vector2.from_angle(k * TAU / 8.0) * radius * ring
			sum += terrain.height_at(p.x, p.y)
			count += 1
	return sum / count


## Keep half of the natural relief inside the walls: buildable, but never flat.
func _level_ground(i: int, x: float, z: float, d: float) -> void:
	var rel := Vector2(x, z) - center()
	var u := d / wall_radius(atan2(rel.y, rel.x))
	var h := terrain.heights[i]
	terrain.heights[i] = lerpf(h, _plateau + (h - _plateau) * 0.5, 1.0 - smoothstep(0.9, 1.35, u))
	if u < 1.05:
		terrain.keep_clear[i] = Terrain.CLEAR_TREES


func _flatten_plaza(i: int, _x: float, _z: float, d: float) -> void:
	var plaza_h := terrain.height_at(center().x, center().y)
	terrain.heights[i] = lerpf(terrain.heights[i], plaza_h, 1.0 - smoothstep(plaza_radius, plaza_radius + 10.0, d))
	if d < plaza_radius + 2.0:
		terrain.keep_clear[i] = Terrain.CLEAR_ALL
	terrain.cobble[i] = maxf(terrain.cobble[i], 1.0 - smoothstep(plaza_radius - 1.0, plaza_radius + 0.5, d))


func _make_streets() -> void:
	for street in STREETS:
		var route := PackedVector2Array()
		for p: Vector2 in street[1]:
			route.append(center() + p * (radius / 105.0))
		var road := Road.create(route, street[0], Road.Surface.COBBLE)
		road.shoulder = 3.0
		road.lanterns = true
		road.terrain = terrain
		add_child(road)
		road.build_path()
		_roads.append(road)
		_road_boxes.append(PathUtil.bounds(road.samples).grow(street[0] * 0.5 + 3.0))


# --- houses -------------------------------------------------------------------

func _plan_houses() -> void:
	seed_rng(1)
	# Town hall facing the plaza from the north.
	_try_house(center() + Vector2(0, -(plaza_radius + 6.0 + 10.0)), 0.0, 6, 4, 3, false, Building.Roof.HIGH)
	for row_offset in [0.0, 13.0]:
		for road in _roads:
			for side in [-1.0, 1.0]:
				_line_street(road, side, row_offset)


## Walks along a street placing houses on one [side]; [row_offset] pushes them back to start
## a second row behind the first.
func _line_street(road: Road, side: float, row_offset: float) -> void:
	var i := 3
	while i < road.samples.size() - 3:
		var w: int = [2, 2, 3, 3, 4][rng.randi() % 5]
		var d := 2 if rng.randf() < 0.65 else 3
		var tangent := PathUtil.tangent(road.samples, i)
		var normal := Vector2(-tangent.y, tangent.x) * side
		var setback := rng.randf_range(1.8, 3.8) + row_offset
		var at := road.samples[i] + normal * (road.width * 0.5 + setback + d * Kit.CELL * 0.5)
		var front := -normal
		var yaw := atan2(front.x, front.y) + rng.randf_range(-0.14, 0.14)
		var floors: int = [1, 1, 2, 2, 3][rng.randi() % 5]
		var roof := Building.Roof.GABLE if floors == 1 and rng.randf() < 0.7 else Building.Roof.HIGH
		var placed := _try_house(at, yaw, w, d, floors, rng.randf() < 0.35, roof)
		var advance := (w * Kit.CELL + rng.randf_range(0.0, 3.0)) / 3.0 if placed else 1.0
		i += ceili(advance)


func _try_house(at: Vector2, yaw: float, w: int, d: int, floors: int, wood: bool, roof: Building.Roof) -> bool:
	var half := Vector2(w, d) * Kit.CELL * 0.5
	if not _fits(at, yaw, half):
		return false
	_houses.append({
		"at": at, "yaw": yaw, "w": w, "d": d, "half": half,
		"floors": floors, "wood": wood, "roof": roof, "y": 0.0,
	})
	return true


func _fits(at: Vector2, yaw: float, half: Vector2) -> bool:
	for p in _rect_points(at, yaw, half + Vector2(1.0, 1.0), 9999.0):
		if p.distance_to(center()) < plaza_radius + 3.0 or not _inside_wall(p, 3.0) or _on_street(p, 1.2):
			return false
	for other in _houses:
		if at.distance_to(other["at"]) > half.length() + other["half"].length() + 2.0:
			continue
		if _overlaps(at, yaw, half, other) or _overlaps(other["at"], other["yaw"], other["half"], {"at": at, "yaw": yaw, "half": half}):
			return false
	return true


## Corners, edge midpoints and center of a rotated rectangle; with a small [step], a full grid.
func _rect_points(at: Vector2, yaw: float, half: Vector2, step: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var nx := 2 if step > 1000.0 else ceili(half.x * 2.0 / step)
	var nz := 2 if step > 1000.0 else ceili(half.y * 2.0 / step)
	for j in nz + 1:
		for i in nx + 1:
			var local := Vector2(lerpf(-half.x, half.x, float(i) / nx), lerpf(-half.y, half.y, float(j) / nz))
			points.append(at + _to_world(local, yaw))
	return points


# Local axes of a house: x = (cos, -sin), z = (sin, cos) in world (x, z).
func _to_world(local: Vector2, yaw: float) -> Vector2:
	return Vector2(cos(yaw) * local.x + sin(yaw) * local.y, -sin(yaw) * local.x + cos(yaw) * local.y)


func _to_local_point(world_offset: Vector2, yaw: float) -> Vector2:
	return Vector2(cos(yaw) * world_offset.x - sin(yaw) * world_offset.y, sin(yaw) * world_offset.x + cos(yaw) * world_offset.y)


func _overlaps(at: Vector2, yaw: float, half: Vector2, other: Dictionary) -> bool:
	var other_half: Vector2 = other["half"] + Vector2(1.0, 1.0)
	for p in _rect_points(at, yaw, half, 2.5):
		var local := _to_local_point(p - other["at"], other["yaw"])
		if absf(local.x) < other_half.x and absf(local.y) < other_half.y:
			return true
	return false


func _inside_wall(p: Vector2, margin: float) -> bool:
	var rel := p - center()
	return rel.length() <= wall_radius(atan2(rel.y, rel.x)) - margin


func _on_street(p: Vector2, margin: float) -> bool:
	for i in _roads.size():
		if _road_boxes[i].has_point(p) and PathUtil.min_distance(_roads[i].samples, p) < _roads[i].width * 0.5 + margin:
			return true
	return false


## Flat pad under the house, blended into the slope around it.
func _level_pad(house: Dictionary) -> void:
	var at: Vector2 = house["at"]
	var half: Vector2 = house["half"]
	var pad_y := terrain.height_at(at.x, at.y)
	house["y"] = pad_y
	terrain.for_cells_in_disc(at, half.length() + 8.0, func(i: int, x: float, z: float, _d: float) -> void:
		var local := _to_local_point(Vector2(x, z) - at, house["yaw"])
		var outside := Vector2(maxf(absf(local.x) - half.x - 1.0, 0.0), maxf(absf(local.y) - half.y - 1.0, 0.0)).length()
		terrain.heights[i] = lerpf(terrain.heights[i], pad_y, 1.0 - smoothstep(0.0, 4.0, outside))
		if outside < 2.0:
			terrain.keep_clear[i] = Terrain.CLEAR_ALL
	)


# --- props --------------------------------------------------------------------

func populate(scatter: Scatter) -> void:
	seed_rng(2)
	_build_wall()
	_build_gate()
	_build_plaza()
	_build_houses()
	_plant_town_trees()
	for road in _roads:
		road.populate(scatter)


func _build_houses() -> void:
	for spec in _houses:
		var house := Node3D.new()
		house.position = to_local(Vector3(spec["at"].x, spec["y"], spec["at"].y))
		house.rotation.y = spec["yaw"]
		add_child(house)
		var nw := Vector3(-(spec["w"] - 1) * 0.5 * Kit.CELL, 0.0, -(spec["d"] - 1) * 0.5 * Kit.CELL)
		Building.build(house, nw, spec["w"], spec["d"], "S", spec["floors"], spec["wood"], spec["roof"])


func _build_wall() -> void:
	var ring := PackedVector2Array()
	for k in 721:
		var angle := TAU * k / 720.0
		ring.append(center() + Vector2.from_angle(angle) * wall_radius(angle))
	var points := PathUtil.resample(ring, WALL_STEP)
	var gate := gate_point()
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		if ((a + b) * 0.5).distance_to(gate) < GATE_CLEAR:
			continue
		wall_piece(a, b, "wall")
		if i % 4 == 0:
			place("town", "pillar-stone", a, 0.0, Kit.Collision.MESH)


## Two stone towers and a lintel, centered on the road axis (the wall tangent here is x).
func _build_gate() -> void:
	var g := gate_point()
	var base := terrain.height_at(g.x, g.y) - 0.6
	for side in [-1.0, 1.0]:
		var x: float = g.x + side * (GATE_HALF + TOWER * 0.5)
		var tower := place_at("town", "wall-block", Vector3(x, base, g.y), 0.0, Kit.Collision.NONE)
		tower.scale = Vector3(TOWER, 9.0, TOWER)
		block_at(Vector3(x, base + 4.5, g.y), Vector3(TOWER, 9.0, TOWER))
		place("town", "lantern", Vector2(x, g.y + TOWER * 0.5 + 1.2))
	var span := GATE_HALF * 2.0 + 0.4
	var lintel := place_at("town", "wall-block", Vector3(g.x, base + 5.2, g.y), 0.0, Kit.Collision.NONE)
	lintel.scale = Vector3(span, 2.8, TOWER - 1.0)
	block_at(Vector3(g.x, base + 5.2 + 1.4, g.y), Vector3(span, 2.8, TOWER - 1.0))


func _build_plaza() -> void:
	var c := center()
	place("town", "fountain-round", c, 0.0, Kit.Collision.MESH, 1.3)
	var stalls := ["stall-red", "stall-green"]
	for k in 8:
		var angle := TAU * (k + 0.5) / 8.0
		var out := Vector2.from_angle(angle)
		var yaw := rad_to_deg(atan2(-out.x, -out.y))
		place("town", stalls[k % 2], c + out * plaza_radius * 0.62, yaw, Kit.Collision.MESH)
	for k in 4:
		var angle := TAU * (k + 0.5) / 4.0 + PI * 0.25
		var out := Vector2.from_angle(angle)
		place("town", "stall-bench", c + out * 10.0, rad_to_deg(atan2(out.x, out.y)))
	for k in 8:
		var angle := TAU * k / 8.0
		place("town", "tree", c + Vector2.from_angle(angle) * (plaza_radius - 3.0), rng.randf() * 360.0, Kit.Collision.TRUNK, 0.9)
	for k in 12:
		place("town", "lantern", c + Vector2.from_angle(TAU * k / 12.0 + 0.2) * (plaza_radius - 0.6))
	place("town", "cart", c + Vector2(-12.0, 8.0), 70.0, Kit.Collision.MESH)
	place("town", "cart", c + Vector2(13.0, -7.0), -110.0, Kit.Collision.MESH)


func _plant_town_trees() -> void:
	var planted := 0
	for attempt in 200:
		if planted >= 30:
			return
		var p := center() + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * radius
		if not _inside_wall(p, 8.0) or p.distance_to(center()) < plaza_radius + 6.0 or _on_street(p, 4.0) or _near_house(p, 3.0):
			continue
		place("town", "tree", p, rng.randf() * 360.0, Kit.Collision.TRUNK, rng.randf_range(0.8, 1.1))
		planted += 1


func _near_house(p: Vector2, margin: float) -> bool:
	for house in _houses:
		var local := _to_local_point(p - house["at"], house["yaw"])
		if absf(local.x) < house["half"].x + margin and absf(local.y) < house["half"].y + margin:
			return true
	return false
