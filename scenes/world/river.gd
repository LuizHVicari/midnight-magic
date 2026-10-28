class_name River
extends Feature
## River or creek along a polyline of (x, z) points. The water surface only ever descends,
## following the smoothed land, and the channel is carved below it with wide, gentle banks.
## It stops where it reaches [end_lake], whose level it joins.

@export var points := PackedVector2Array()
## Channel half-width at the source; it widens downstream.
@export var width := 6.0
@export var depth := 1.3
var end_lake: Lake

var _path := PackedVector2Array()
var _level := PackedFloat32Array()
var _half_width := PackedFloat32Array()
var _cut := PackedFloat32Array()


static func create(route: PackedVector2Array, half_width: float, channel_depth: float, lake: Lake = null) -> River:
	var river := River.new()
	river.points = route
	river.width = half_width
	river.depth = channel_depth
	river.end_lake = lake
	return river


func _init() -> void:
	priority = 25


func shape() -> void:
	_path = PathUtil.smooth(points, 4.0)
	_trim_at_lake()
	_build_profile()
	var reach := 0.0
	for i in _path.size():
		reach = maxf(reach, _half_width[i] * 2.6 + _cut[i] * 4.0)
	terrain.for_cells_near(_path, reach, _carve)


## Cut the path at the first sample inside the lake so the channel does not dig into its bed.
func _trim_at_lake() -> void:
	if end_lake == null:
		return
	for i in _path.size():
		if end_lake.relative_distance(_path[i]) < 0.95:
			_path = _path.slice(0, i + 1)
			return


func _build_profile() -> void:
	var count := _path.size()
	var natural := PackedFloat32Array()
	for p in _path:
		natural.append(terrain.height_at(p.x, p.y))
	var smoothed := PathUtil.blur(natural, 20)

	# Water never climbs: running minimum of the smoothed land height.
	_level.resize(count)
	var lowest := INF
	for i in count:
		lowest = minf(lowest, smoothed[i])
		_level[i] = lowest
	if end_lake != null:
		_join_lake()

	_half_width.resize(count)
	_cut.resize(count)
	for i in count:
		_half_width[i] = width * (0.75 + 0.5 * float(i) / count)
		_cut[i] = maxf(smoothed[i] - _level[i], 0.0)


## Over the last stretch, ease the water surface onto the lake level.
func _join_lake() -> void:
	var count := _path.size()
	var tail := mini(count, 14)
	for i in count:
		_level[i] = maxf(_level[i], end_lake.level)
	for k in tail:
		var i := count - tail + k
		var t := float(k + 1) / tail
		_level[i] = lerpf(_level[i], end_lake.level, t * t)


func _at(values: PackedFloat32Array, along: float) -> float:
	var i := mini(int(along), values.size() - 1)
	return lerpf(values[i], values[mini(i + 1, values.size() - 1)], along - i)


func _carve(i: int, dist: float, along: float) -> void:
	var level := _at(_level, along)
	var half := _at(_half_width, along)
	var bank := half * 1.6 + _at(_cut, along) * 4.0
	var target := level + (dist - half) * 0.35
	if dist < half:
		var u := dist / half
		target = level - depth * (1.0 - u * u)
	var blend := 1.0 - smoothstep(half, half + bank, dist)
	terrain.heights[i] = lerpf(terrain.heights[i], target, blend)
	if dist < half * 1.25:
		terrain.water_y[i] = level
		terrain.flow[i] = PathUtil.tangent(_path, int(along))
	if dist < half * 1.4:
		terrain.keep_clear[i] = Terrain.CLEAR_TREES


func populate(scatter: Scatter) -> void:
	seed_rng(5)
	for i in range(2, _path.size() - 2, 2):
		if rng.randf() > 0.3:
			continue
		var side := Vector2(-PathUtil.tangent(_path, i).y, PathUtil.tangent(_path, i).x)
		var p := _path[i] + side * rng.randf_range(-0.8, 0.8) * _half_width[i]
		var model := "rock_smallA" if rng.randf() < 0.5 else "stone_smallB"
		scatter.add("nature", model, Vector3(p.x, _level[i] - 0.25, p.y), rng.randf() * TAU, rng.randf_range(0.7, 1.4))
