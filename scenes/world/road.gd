class_name Road
extends Feature
## Road along a polyline of (x, z) points. Its surface follows a smoothed version of the land
## (cut and fill), is painted onto the terrain as dirt or cobblestones and, where it crosses
## water, gets a wooden bridge. Optional lanterns line the sides.

enum Surface { DIRT, COBBLE }

const BRIDGE_PIECE := 5.0
## Height of the Kenney bridge deck above its model origin, in world meters.
const BRIDGE_DECK := 0.15 * 5.0
const LANTERN_EVERY := 6  # samples

@export var points := PackedVector2Array()
@export var width := 6.0
@export var shoulder := 7.0
@export var surface := Surface.DIRT
@export var lanterns := false

## Smoothed centerline, one sample every 3 m. Available after [build_path].
var samples := PackedVector2Array()
var _profile := PackedFloat32Array()


static func create(route: PackedVector2Array, road_width := 6.0, road_surface := Surface.DIRT) -> Road:
	var road := Road.new()
	road.points = route
	road.width = road_width
	road.surface = road_surface
	return road


func _init() -> void:
	priority = 30


func build_path() -> void:
	if samples.is_empty():
		samples = PathUtil.smooth(points, 3.0)


func shape() -> void:
	build_path()
	var natural := PackedFloat32Array()
	for p in samples:
		natural.append(terrain.height_at(p.x, p.y))
	_profile = PathUtil.blur(natural, 8)
	terrain.for_cells_near(samples, width * 0.5 + shoulder, _carve)


func _carve(i: int, dist: float, along: float) -> void:
	# Never fill in a river bed; the bridge spans it instead.
	if terrain.water_y[i] > Terrain.NO_WATER * 0.5 and terrain.heights[i] < terrain.water_y[i] + 0.5:
		return
	var half := width * 0.5
	var index := mini(int(along), samples.size() - 1)
	var y := lerpf(_profile[index], _profile[mini(index + 1, samples.size() - 1)], along - index)
	terrain.heights[i] = lerpf(terrain.heights[i], y, 1.0 - smoothstep(half, half + shoulder, dist))
	var mask := 1.0 - smoothstep(half - 0.6, half + 0.4, dist)
	if surface == Surface.COBBLE:
		terrain.cobble[i] = maxf(terrain.cobble[i], mask)
	else:
		terrain.dirt[i] = maxf(terrain.dirt[i], mask)
	if dist < half + 2.5:
		terrain.keep_clear[i] = Terrain.CLEAR_ALL


func populate(_scatter: Scatter) -> void:
	_build_bridges()
	if lanterns:
		_place_lanterns()


func _over_water(p: Vector2) -> bool:
	var i := terrain.index_at(p.x, p.y)
	return terrain.water_y[i] > Terrain.NO_WATER * 0.5 and terrain.water_y[i] > terrain.heights[i] - 0.6


func _build_bridges() -> void:
	var run_start := -1
	for i in samples.size() + 1:
		var wet := i < samples.size() and _over_water(samples[i])
		if wet and run_start < 0:
			run_start = i
		elif not wet and run_start >= 0:
			_bridge(run_start, i - 1)
			run_start = -1


## Straight run of deck pieces from dry land to dry land, level with the road at both ends.
func _bridge(first: int, last: int) -> void:
	var from_i := maxi(first - 3, 0)
	var to_i := mini(last + 3, samples.size() - 1)
	var a := samples[from_i]
	var b := samples[to_i]
	var dir := (b - a).normalized()
	var yaw := rad_to_deg(atan2(-dir.y, dir.x))
	var pieces := ceili(a.distance_to(b) / BRIDGE_PIECE)
	for k in pieces:
		var f := (k + 0.5) / pieces
		var at := a.lerp(b, f)
		var deck := lerpf(_profile[from_i], _profile[to_i], f) + 0.1
		place_at("nature", "bridge_wood", Vector3(at.x, deck - BRIDGE_DECK, at.y), yaw, Kit.Collision.MESH)


func _place_lanterns() -> void:
	var side := 1.0
	for i in range(LANTERN_EVERY, samples.size() - 1, LANTERN_EVERY):
		if _over_water(samples[i]):
			continue
		var tangent := PathUtil.tangent(samples, i)
		var normal := Vector2(-tangent.y, tangent.x)
		place("town", "lantern", samples[i] + normal * side * (width * 0.5 + 0.9))
		side = -side
