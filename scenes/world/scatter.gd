class_name Scatter
extends Node3D
## Batches repeated props (trees, grass, rocks) into MultiMeshes per BLOCK x BLOCK meters, so a
## forest costs a few draw calls instead of thousands of nodes. Add everything with [add],
## then call [flush] once. Solid props get cylinder colliders, one body per block.

const BLOCK := 100.0

## NONE walks through, TRUNK only collides at the base, ROCK collides across its footprint.
enum Solid { NONE, TRUNK, ROCK }

var _batches := {}  # key -> {"pack", "model", "block", "range", "shadows", "xforms"}
var _solids := {}  # block key -> Array of [Vector3 center, float radius, float height]
var _parts := {}  # "pack/model" -> {"parts": [[Mesh, Transform3D]], "aabb": AABB}


func add(
	pack: String,
	model: String,
	pos: Vector3,
	yaw := 0.0,
	scale_mult := 1.0,
	solid := Solid.NONE,
	range_end := 140.0,
	shadows := false,
) -> void:
	var world_scale: float = Kit.PACK_SCALE[pack] * scale_mult
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
		_add_solid(block, model_aabb(pack, model), pos, world_scale, solid)


func flush() -> void:
	for key in _batches:
		_build_batch(_batches[key])
	for block in _solids:
		_build_solids(block, _solids[block])
	_batches.clear()
	_solids.clear()


func model_aabb(pack: String, model: String) -> AABB:
	return _model_parts(pack, model)["aabb"]


func _add_solid(block: Vector2i, aabb: AABB, pos: Vector3, world_scale: float, solid: Solid) -> void:
	var radius := 0.1 * world_scale
	var height := 0.8 * world_scale
	if solid == Solid.ROCK:
		radius = 0.4 * maxf(aabb.size.x, aabb.size.z) * world_scale
		height = maxf(aabb.size.y * world_scale, 0.5)
	if not _solids.has(block):
		_solids[block] = []
	_solids[block].append([pos + Vector3(0.0, height * 0.5, 0.0), radius, height])


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
	var shapes := {}
	for solid in solids:
		var key := Vector2(snappedf(solid[1], 0.05), snappedf(solid[2], 0.05))
		if not shapes.has(key):
			var cylinder := CylinderShape3D.new()
			cylinder.radius = key.x
			cylinder.height = key.y
			shapes[key] = cylinder
		var collider := CollisionShape3D.new()
		collider.shape = shapes[key]
		collider.position = solid[0] - center
		body.add_child(collider)
	add_child(body)


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
	_parts[key] = {"parts": parts, "aabb": aabb}
	return _parts[key]


func _relative_transform(node: Node3D, root: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var current: Node = node
	while current != root:
		xf = (current as Node3D).transform * xf
		current = current.get_parent()
	return xf
