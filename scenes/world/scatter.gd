class_name Scatter
extends Node3D
## Batches repeated props (trees, grass, rocks) into MultiMeshes per BLOCK x BLOCK meters, so a
## forest costs a few draw calls instead of thousands of nodes. Add everything with [add],
## then call [flush] once. Solid props get colliders, one body per block: trees a cylinder
## sized from the real trunk, rocks their exact mesh.

const BLOCK := 100.0

## NONE walks through, TRUNK only collides at the trunk, ROCK follows the shape of the rock.
enum Solid { NONE, TRUNK, ROCK }

## Set by the world; lets [add] sit rocks on the lowest point under them.
var terrain: Terrain

var _batches := {}  # key -> {"pack", "model", "block", "range", "shadows", "xforms"}
var _solids := {}  # block -> Array of {"solid", "pack", "model", "xf"}
var _parts := {}  # "pack/model" -> {"parts": [[Mesh, Transform3D]], "aabb": AABB, "trunk": float, "rocks": []}
var _cylinders := {}  # Vector2(radius, height) -> CylinderShape3D


func add(
	pack: String,
	model: String,
	pos: Vector3,
	yaw := 0.0,
	scale_mult := 1.0,
	solid := Solid.NONE,
	range_end := 140.0,
	shadows := false,
	fit_ground := false,
) -> void:
	var world_scale: float = Kit.PACK_SCALE[pack] * scale_mult
	if fit_ground and terrain != null:
		pos.y = _lowest_under(pack, model, pos, world_scale)
	var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * world_scale)
	var block := Vector2i(floori(pos.x / BLOCK), floori(pos.z / BLOCK))
	var key := "%s/%s|%d|%d|%d|%s" % [pack, model, block.x, block.y, int(range_end), shadows]
	if not _batches.has(key):
		_batches[key] = {
			"pack": pack, "model": model, "block": block, "range": range_end,
			"shadows": shadows, "xforms": [],
		}
	_batches[key]["xforms"].append(Transform3D(basis, pos))

	if solid != Solid.NONE:
		if not _solids.has(block):
			_solids[block] = []
		_solids[block].append({"solid": solid, "pack": pack, "model": model, "xf": Transform3D(basis, pos)})


func flush() -> void:
	for key in _batches:
		_build_batch(_batches[key])
	for block in _solids:
		_build_solids(block, _solids[block])
	_batches.clear()
	_solids.clear()


func model_aabb(pack: String, model: String) -> AABB:
	return _model_parts(pack, model)["aabb"]


## Rocks rest on the lowest ground under their footprint and sink a little, so a slope never
## leaves them floating on the downhill side.
func _lowest_under(pack: String, model: String, pos: Vector3, world_scale: float) -> float:
	var aabb := model_aabb(pack, model)
	var radius := 0.4 * maxf(aabb.size.x, aabb.size.z) * world_scale
	return terrain.lowest_around(pos.x, pos.z, radius) - 0.1 * aabb.size.y * world_scale


func _block_center(block: Vector2i) -> Vector3:
	return Vector3((block.x + 0.5) * BLOCK, 0.0, (block.y + 0.5) * BLOCK)


func _build_batch(batch: Dictionary) -> void:
	var center := _block_center(batch["block"])
	var xforms: Array = batch["xforms"]
	for part in _model_parts(batch["pack"], batch["model"])["parts"]:
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = part[0]
		multi.instance_count = xforms.size()
		for i in xforms.size():
			var xf: Transform3D = xforms[i]
			multi.set_instance_transform(i, Transform3D(xf.basis, xf.origin - center) * part[1])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multi
		instance.position = center
		instance.visibility_range_end = batch["range"]
		if not batch["shadows"]:
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)


func _build_solids(block: Vector2i, solids: Array) -> void:
	var center := _block_center(block)
	var body := StaticBody3D.new()
	body.position = center
	for solid in solids:
		var xf: Transform3D = solid["xf"]
		var local := Transform3D(xf.basis, xf.origin - center)
		var data := _model_parts(solid["pack"], solid["model"])
		if solid["solid"] == Solid.TRUNK:
			_add_trunk(body, data, local)
		else:
			_add_rock(body, data, local)
	add_child(body)


func _add_trunk(body: StaticBody3D, data: Dictionary, local: Transform3D) -> void:
	var world_scale := local.basis.get_scale().x
	var aabb: AABB = data["aabb"]
	var key := Vector2(snappedf(data["trunk"] * world_scale, 0.05), snappedf(aabb.size.y * world_scale * 0.5, 0.25))
	if not _cylinders.has(key):
		var cylinder := CylinderShape3D.new()
		cylinder.radius = key.x
		cylinder.height = key.y
		_cylinders[key] = cylinder
	var collider := CollisionShape3D.new()
	collider.shape = _cylinders[key]
	collider.position = local.origin + Vector3(0.0, key.y * 0.5, 0.0)
	body.add_child(collider)


func _add_rock(body: StaticBody3D, data: Dictionary, local: Transform3D) -> void:
	for rock in data["rocks"]:
		var collider := CollisionShape3D.new()
		collider.shape = rock[0]
		collider.transform = local * rock[1]
		body.add_child(collider)


## Meshes of a Kenney model with their transform relative to the model root.
func _model_parts(pack: String, model: String) -> Dictionary:
	var key := "%s/%s" % [pack, model]
	if _parts.has(key):
		return _parts[key]
	var root: Node3D = load(Kit.MODEL_PATH % [pack, model]).instantiate()
	var parts := []
	var aabb := AABB()
	var first := true
	for mesh_node in root.find_children("*", "MeshInstance3D", true, false):
		var xf := _relative_transform(mesh_node, root)
		parts.append([mesh_node.mesh, xf])
		aabb = (xf * mesh_node.get_aabb()) if first else aabb.merge(xf * mesh_node.get_aabb())
		first = false
	root.free()
	_parts[key] = {"parts": parts, "aabb": aabb, "trunk": _trunk_radius(parts, aabb), "rocks": _rock_shapes(parts)}
	return _parts[key]


## Widest reach of the lowest slice of the model: the trunk, roots included, capped so a low
## wide crown never turns into an invisible wall.
func _trunk_radius(parts: Array, aabb: AABB) -> float:
	var limit := aabb.position.y + aabb.size.y * 0.08
	var widest := 0.0
	for part in parts:
		for v in part[0].get_faces():
			var p: Vector3 = part[1] * v
			if p.y <= limit:
				widest = maxf(widest, Vector2(p.x, p.z).length())
	return clampf(widest, 0.02, 0.14)


## Exact triangle collision, shared by every instance of the model. A convex hull would fill
## in the ledges and steps of the rocks, leaving invisible slopes.
func _rock_shapes(parts: Array) -> Array:
	var shapes := []
	for part in parts:
		var shape: ConcavePolygonShape3D = part[0].create_trimesh_shape()
		shape.backface_collision = true
		shapes.append([shape, part[1]])
	return shapes


func _relative_transform(node: Node3D, root: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var current: Node = node
	while current != root:
		xf = (current as Node3D).transform * xf
		current = current.get_parent()
	return xf
