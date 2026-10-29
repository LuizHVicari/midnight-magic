class_name Feature
extends Node3D
## Base of every map component (lake, river, road, clearing, town...). The world runs
## [shape] on all features, lowest [priority] first, while the terrain is still just arrays,
## then [populate] once heights are final. Features that carve the ground must run before
## the ones that need it to stay put: lakes, town, roads, rivers, clearings.

@export var priority := 0

var terrain: Terrain
var rng := RandomNumberGenerator.new()


## Edit the terrain arrays (height, paint, water, keep_clear).
func shape() -> void:
	pass


## Place props. Heights are final here.
func populate(_scatter: Scatter) -> void:
	pass


## 2D (x, z) position of the node.
func center() -> Vector2:
	return Vector2(position.x, position.z)


func seed_rng(salt := 0) -> void:
	rng.seed = hash(Vector3i(roundi(global_position.x), roundi(global_position.z), salt))


## Places a Kit model standing on the terrain at world (x, z), [lift] meters above it.
func place(
	pack: String,
	model: String,
	at: Vector2,
	yaw_deg := 0.0,
	collision := Kit.Collision.AUTO,
	scale_mult := 1.0,
	lift := 0.0,
) -> Node3D:
	var y := terrain.height_at(at.x, at.y)
	if model.begins_with("rock") or model.begins_with("stone") or model.begins_with("statue"):
		# Rest on the lowest ground under the footprint, a bit sunk, so slopes never leave a gap.
		y = terrain.lowest_around(at.x, at.y, 0.25 * Kit.PACK_SCALE[pack] * scale_mult) - 0.15
	var pos := Vector3(at.x, y + lift, at.y)
	var piece := place_at(pack, model, pos, yaw_deg, collision, scale_mult)
	if model == "lantern":
		add_night_light(pos + Vector3.UP * 6.8, Color(1.0, 0.78, 0.45), 2.6, 13.0)
	return piece


## Same as [place] with an explicit world position.
func place_at(
	pack: String,
	model: String,
	world_pos: Vector3,
	yaw_deg := 0.0,
	collision := Kit.Collision.AUTO,
	scale_mult := 1.0,
) -> Node3D:
	return Kit.place(self, pack, model, to_local(world_pos), yaw_deg, collision, scale_mult)


## A lamp that lights up at night (see [NightLight]) at a world position.
func add_night_light(world_pos: Vector3, color: Color, energy: float, reach: float, flickers := false) -> void:
	var light := NightLight.make(color, energy, reach, flickers)
	add_child(light)
	light.position = to_local(world_pos)


## Solid invisible box at a world position (collision for scaled or merged visuals).
func block_at(world_center: Vector3, size: Vector3, yaw_deg := 0.0) -> void:
	Kit.add_block(self, to_local(world_center), size, yaw_deg)


## One 5 m piece of Kenney town wall laid along the chord a -> b and tilted to follow the
## ground, so walls climb hills instead of floating over them.
func wall_piece(a: Vector2, b: Vector2, model := "wall") -> void:
	var dir := (b - a).normalized()
	var yaw := atan2(dir.x, dir.y)
	var across := Vector2(cos(yaw), -sin(yaw))
	# The thin wall sits at +0.45 cells on the model's local x axis.
	var origin := (a + b) * 0.5 - across * (0.45 * Kit.CELL)
	var ha := terrain.height_at(a.x, a.y)
	var hb := terrain.height_at(b.x, b.y)
	var pitch := -atan2(hb - ha, a.distance_to(b))
	var piece := place_at(
		"town", model, Vector3(origin.x, (ha + hb) * 0.5 - 0.3, origin.y), 0.0, Kit.Collision.MESH,
	)
	piece.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch) * Basis.from_scale(piece.scale)
