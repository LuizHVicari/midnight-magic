class_name Clearing
extends Feature
## Reusable forest clearing: flattens a patch of ground, rings it with trees and dresses it
## according to [kind]. Drop as many as the map needs; each one is seeded by its position,
## so no two look the same. Skipped automatically if it would land in water.

enum Kind { MEADOW, CAMP, STONES, RUINS }

const TALL_STONES := ["stone_tallA", "stone_tallB", "stone_tallC", "rock_tallA", "rock_tallD"]
const RUIN_WALLS := ["wall", "wall-broken", "wall-half", "wall-broken"]

@export var kind := Kind.MEADOW
@export var radius := 22.0

var _ground := 0.0
var _valid := true


static func create(clearing_kind: Kind, at: Vector2, clearing_radius := 22.0) -> Clearing:
	var clearing := Clearing.new()
	clearing.kind = clearing_kind
	clearing.position = Vector3(at.x, 0.0, at.y)
	clearing.radius = clearing_radius
	return clearing


func _init() -> void:
	priority = 50


func shape() -> void:
	_valid = _is_dry()
	if not _valid:
		push_warning("Clearing %s at %s is in water, skipped" % [Kind.keys()[kind], center()])
		return
	_ground = terrain.height_at(center().x, center().y)
	terrain.for_cells_in_disc(center(), radius * 1.6, _flatten)


func _is_dry() -> bool:
	for k in 9:
		var p := center() if k == 8 else center() + Vector2.from_angle(k * TAU / 8.0) * radius
		if terrain.water_y[terrain.index_at(p.x, p.y)] > Terrain.NO_WATER * 0.5:
			return false
	return true


func _flatten(i: int, _x: float, _z: float, d: float) -> void:
	terrain.heights[i] = lerpf(terrain.heights[i], _ground, 1.0 - smoothstep(radius * 0.75, radius * 1.6, d))
	if d < radius * 1.05:
		terrain.keep_clear[i] = Terrain.CLEAR_ALL
	if kind == Kind.CAMP:
		terrain.dirt[i] = maxf(terrain.dirt[i], (1.0 - smoothstep(radius * 0.3, radius * 0.55, d)) * 0.8)


func populate(scatter: Scatter) -> void:
	if not _valid:
		return
	seed_rng(int(kind))
	_ring_of_trees(scatter)
	match kind:
		Kind.MEADOW:
			_meadow(scatter)
		Kind.CAMP:
			_camp()
		Kind.STONES:
			_stones(scatter)
		Kind.RUINS:
			_ruins()


func _on_disc(fraction: float) -> Vector2:
	return center() + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * radius * fraction


func _ring_of_trees(scatter: Scatter) -> void:
	var count := int(TAU * radius * 1.4 / 7.0)
	for k in count:
		if rng.randf() < 0.25:
			continue
		var angle := TAU * k / count + rng.randf_range(-0.1, 0.1)
		var p := center() + Vector2.from_angle(angle) * radius * rng.randf_range(1.2, 1.7)
		var h := terrain.height_at(p.x, p.y)
		scatter.add(
			"nature", Vegetation.tree_model(rng, h), Vector3(p.x, h, p.y), rng.randf() * TAU,
			Vegetation.tree_scale(rng), Scatter.Solid.TRUNK, 420.0, true,
		)


func _meadow(scatter: Scatter) -> void:
	for k in int(radius * 9.0):
		var p := _on_disc(1.0)
		var flowers := rng.randf() < 0.85
		var pool: Array = Vegetation.FLOWERS if flowers else Vegetation.MUSHROOMS
		var size := Vegetation.FLOWER_SIZE if flowers else Vegetation.MUSHROOM_SIZE
		var model: String = pool[rng.randi() % pool.size()]
		var pos := Vector3(p.x, terrain.height_at(p.x, p.y), p.y)
		scatter.add("nature", model, pos, rng.randf() * TAU, rng.randf_range(0.9, 1.5) * size)
	for k in 2:
		place("nature", "log", _on_disc(0.8), rng.randf() * 360.0)
	for k in 3:
		place("nature", "stump_round", _on_disc(0.8), rng.randf() * 360.0)


func _camp() -> void:
	var fire := center()
	place("survival", "campfire-pit", fire, 0.0, Kit.Collision.MESH)
	place("nature", "log", fire + Vector2(5.0, 1.8), 80.0, Kit.Collision.MESH)
	place("nature", "log", fire + Vector2(-5.0, -1.5), 100.0, Kit.Collision.MESH)
	place("nature", "log", fire + Vector2(0.5, 5.5), 10.0, Kit.Collision.MESH)
	place("survival", "tent", fire + Vector2(-9.0, 9.5), 150.0, Kit.Collision.MESH)
	place("survival", "tent", fire + Vector2(9.5, 9.0), 215.0, Kit.Collision.MESH)
	place("survival", "tent-canvas", fire + Vector2(0.5, -12.5), 0.0, Kit.Collision.MESH)
	place("survival", "bedroll", fire + Vector2(-3.5, 5.0), 30.0)
	place("survival", "barrel", fire + Vector2(-12.0, -3.5), 0.0, Kit.Collision.MESH)
	place("survival", "box", fire + Vector2(-11.2, -7.0), 20.0, Kit.Collision.MESH)
	place("survival", "box-large", fire + Vector2(-13.0, -9.0), 50.0, Kit.Collision.MESH)
	place("survival", "chest", fire + Vector2(11.5, -6.5), -30.0, Kit.Collision.MESH)
	place("survival", "workbench", fire + Vector2(12.5, 0.0), -90.0, Kit.Collision.MESH)
	place("survival", "signpost", fire + Vector2(-radius * 0.8, radius * 0.6), 20.0, Kit.Collision.MESH)


func _stones(scatter: Scatter) -> void:
	var count := 9
	for k in count:
		var angle := TAU * k / count + rng.randf_range(-0.08, 0.08)
		var p := center() + Vector2.from_angle(angle) * radius * 0.55
		var model: String = TALL_STONES[rng.randi() % TALL_STONES.size()]
		place("nature", model, p, rad_to_deg(-angle) + rng.randf_range(-15.0, 15.0), Kit.Collision.MESH, rng.randf_range(1.2, 1.7))
	place("nature", "statue_obelisk", center(), rng.randf() * 360.0, Kit.Collision.MESH, 1.6)
	for k in 6:
		var p := _on_disc(0.45)
		var pos := Vector3(p.x, terrain.height_at(p.x, p.y), p.y)
		scatter.add("nature", "mushroom_redGroup", pos, rng.randf() * TAU, rng.randf_range(1.0, 1.6) * Vegetation.MUSHROOM_SIZE)


## A collapsed rectangular enclosure: walls with gaps, broken pillars and rubble.
func _ruins() -> void:
	var half := Vector2(radius * 0.55, radius * 0.38)
	var yaw := rng.randf() * TAU
	var loop: Array[Vector2] = []
	for offset in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		loop.append(center() + (offset * half).rotated(yaw))
	for s in 4:
		_ruined_wall(loop[s], loop[(s + 1) % 4])
	for corner in loop:
		place("town", "pillar-stone", corner, 0.0, Kit.Collision.MESH, rng.randf_range(0.5, 1.0))
	place("nature", "statue_columnDamaged", center(), rng.randf() * 360.0, Kit.Collision.MESH, 1.4)
	for k in 5:
		var model := "rock_largeA" if k % 2 == 0 else "rock_smallE"
		place("nature", model, _on_disc(0.7), rng.randf() * 360.0, Kit.Collision.MESH, rng.randf_range(0.8, 1.4))


func _ruined_wall(a: Vector2, b: Vector2) -> void:
	var pieces := maxi(roundi(a.distance_to(b) / Kit.CELL), 1)
	for k in pieces:
		if rng.randf() < 0.35:
			continue
		var from_p := a.lerp(b, float(k) / pieces)
		var to_p := a.lerp(b, float(k + 1) / pieces)
		wall_piece(from_p, to_p, RUIN_WALLS[rng.randi() % RUIN_WALLS.size()])
