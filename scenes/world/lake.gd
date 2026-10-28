class_name Lake
extends Feature
## Irregular lake: carves a bowl, lets the banks rise gently into the surrounding land and
## floats lilies on the shallows. [level] is the water height, known after [shape].

@export var radius := 70.0
@export var depth := 2.4

var level := 0.0
var _shore := FastNoiseLite.new()


static func create(at: Vector2, lake_radius: float, lake_depth := 2.4) -> Lake:
	var lake := Lake.new()
	lake.position = Vector3(at.x, 0.0, at.y)
	lake.radius = lake_radius
	lake.depth = lake_depth
	return lake


func _init() -> void:
	priority = 10
	_shore.frequency = 0.6
	_shore.fractal_octaves = 2


## Shore radius towards [angle]: a circle wobbled by noise.
func shore_radius(angle: float) -> float:
	return radius * (1.0 + 0.28 * _shore.get_noise_2d(cos(angle) * 2.0, sin(angle) * 2.0))


## Distance from the center in units of the local shore radius; < 1 is inside the lake.
func relative_distance(p: Vector2) -> float:
	var rel := p - center()
	return rel.length() / shore_radius(atan2(rel.y, rel.x))


func shape() -> void:
	_shore.seed = hash(center())
	level = _mean_height() - 0.8
	terrain.for_cells_in_disc(center(), radius * 1.4 * 1.8, _carve)


func _mean_height() -> float:
	var sum := terrain.height_at(center().x, center().y)
	for k in 8:
		var p := center() + Vector2.from_angle(k * TAU / 8.0) * radius * 0.6
		sum += terrain.height_at(p.x, p.y)
	return sum / 9.0


func _carve(i: int, x: float, z: float, _d: float) -> void:
	var u := relative_distance(Vector2(x, z))
	if u > 1.8:
		return
	var rr := shore_radius(atan2(z - position.z, x - position.x))
	var target := level + (u - 1.0) * rr * 0.1
	if u < 1.0:
		target = level - depth * (1.0 - u * u)
	terrain.heights[i] = lerpf(terrain.heights[i], target, 1.0 - smoothstep(1.0, 1.8, u))
	if u < 1.15:
		terrain.water_y[i] = level
	if u < 1.25:
		terrain.keep_clear[i] = Terrain.CLEAR_TREES


func populate(scatter: Scatter) -> void:
	seed_rng(11)
	for k in int(radius * 1.2):
		var p := center() + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * radius
		var water_depth := level - terrain.heights[terrain.index_at(p.x, p.y)]
		if water_depth < 0.25 or water_depth > 1.6 or relative_distance(p) > 0.95:
			continue
		var model := "lily_large" if rng.randf() < 0.6 else "lily_small"
		scatter.add("nature", model, Vector3(p.x, level + 0.04, p.y), rng.randf() * TAU, rng.randf_range(0.8, 1.4))
