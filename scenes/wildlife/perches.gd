class_name Perches
extends RefCounted
## Where birds can sit. Every tree placed by the [Scatter] registers itself here with its height
## and crown size, so a bird can ask for a perch near any point: a spot on the outside of a
## random tree's crown. Trees are kept in a coarse grid, so lookups stay cheap on a big map.
## Spots are on the crown's outside. The registry is static: [method clear] it before building a new world.

const CELL := 40.0

static var _trees := PackedVector3Array()  # where each tree stands
static var _crowns := PackedVector2Array()  # crown height and radius, per tree
static var _grid := {}  # Vector2i -> PackedInt32Array of tree indices


static func clear() -> void:
	_trees.clear()
	_crowns.clear()
	_grid.clear()


static func add(ground: Vector3, crown_height: float, crown_radius: float) -> void:
	_trees.append(ground)
	_crowns.append(Vector2(crown_height, crown_radius))
	var cell := _cell(ground)
	var list: PackedInt32Array = _grid.get(cell, PackedInt32Array())
	list.append(_trees.size() - 1)
	_grid[cell] = list


## How many trees stand within [param radius] of the point on the flat.
static func count_near(at: Vector3, radius: float) -> int:
	return _near(at, radius).size()


## A perch on a random tree within [param radius] of [param at], or [constant Vector3.INF] when
## there is no tree there.
static func pick_near(at: Vector3, radius: float, rng: RandomNumberGenerator) -> Vector3:
	var trees := _near(at, radius)
	if trees.is_empty():
		return Vector3.INF
	return _perch_on(trees[rng.randi() % trees.size()], rng)


## A spot on the outside of tree [param index]'s crown, where a bird can actually be seen: mostly
## on the very top, sometimes out on the side. Never inside the leaves.
static func _perch_on(index: int, rng: RandomNumberGenerator) -> Vector3:
	var crown := _crowns[index]
	var base := _trees[index]
	if rng.randf() < 0.7:
		var offset := Vector2.from_angle(rng.randf() * TAU) * crown.y * rng.randf_range(0.0, 0.3)
		return base + Vector3(offset.x, crown.x * 0.99, offset.y)
	var side := Vector2.from_angle(rng.randf() * TAU) * crown.y * 0.8
	return base + Vector3(side.x, crown.x * rng.randf_range(0.5, 0.7), side.y)


static func _near(at: Vector3, radius: float) -> PackedInt32Array:
	var found := PackedInt32Array()
	var low := _cell(at - Vector3(radius, 0.0, radius))
	var high := _cell(at + Vector3(radius, 0.0, radius))
	for x in range(low.x, high.x + 1):
		for y in range(low.y, high.y + 1):
			for index in _grid.get(Vector2i(x, y), PackedInt32Array()):
				var flat := Vector2(_trees[index].x - at.x, _trees[index].z - at.z)
				if flat.length() <= radius:
					found.append(index)
	return found


static func _cell(at: Vector3) -> Vector2i:
	return Vector2i(floori(at.x / CELL), floori(at.z / CELL))
