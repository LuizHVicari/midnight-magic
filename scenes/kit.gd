class_name Kit
## Helpers to place Kenney kit models in the world at a consistent scale.

const CELL := 5.0
const MODEL_PATH := "res://assets/models/kenney/%s/%s.glb"
## Kenney packs use different unit sizes, so each gets its own world scale.
const PACK_SCALE := {"nature": 5.0, "survival": 8.0, "town": 5.0}

## AUTO picks the collision from the model name (see _auto_collision), so a rock always
## blocks the player no matter where it is placed. Pass NONE to opt out.
enum Collision { AUTO, NONE, MESH, TRUNK }

## Model-name prefixes that always collide. Foliage (grass, flowers, bushes, mushrooms),
## ground tiles and banners are deliberately absent: they are walk-through or have their
## own terrain collision.
const TRUNK_PREFIXES := ["tree"]
const MESH_PREFIXES := [
	"rock", "stone", "log", "cliff", "statue", "bridge", "campfire", "tent", "barrel", "box",
	"chest", "workbench", "signpost", "sign", "fountain", "stall", "cart", "windmill",
	"watermill", "pillar", "lantern", "hedge", "fence", "wall",
]


## World position of a grid cell center. Column/row can be fractional.
static func cell_pos(col: float, row: float, origin_col: float, origin_row: float) -> Vector3:
	return Vector3((col - origin_col) * CELL, 0.0, (row - origin_row) * CELL)


static func place(
	parent: Node3D,
	pack: String,
	model: String,
	pos: Vector3,
	yaw_deg := 0.0,
	collision := Collision.AUTO,
	scale_mult := 1.0,
) -> Node3D:
	var inst: Node3D = load(MODEL_PATH % [pack, model]).instantiate()
	inst.position = pos
	inst.rotation_degrees.y = yaw_deg
	inst.scale = Vector3.ONE * PACK_SCALE[pack] * scale_mult
	parent.add_child(inst)
	if collision == Collision.AUTO:
		collision = _auto_collision(model)
	match collision:
		Collision.MESH:
			_add_mesh_collision(inst)
		Collision.TRUNK:
			_add_trunk_collision(parent, pos, PACK_SCALE[pack] * scale_mult)
	return inst


static func _auto_collision(model: String) -> Collision:
	for prefix in TRUNK_PREFIXES:
		if model.begins_with(prefix):
			return Collision.TRUNK
	for prefix in MESH_PREFIXES:
		if model.begins_with(prefix):
			return Collision.MESH
	return Collision.NONE


## Invisible solid box, used to keep the player out of buildings.
static func add_block(parent: Node3D, center: Vector3, size: Vector3, yaw_deg := 0.0) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = center
	body.rotation_degrees.y = yaw_deg
	parent.add_child(body)


static func _add_mesh_collision(node: Node) -> void:
	if node is MeshInstance3D:
		node.create_trimesh_collision()
	for child in node.get_children():
		_add_mesh_collision(child)


## Trees only collide at the trunk, which is cheaper than the full canopy mesh.
static func _add_trunk_collision(parent: Node3D, pos: Vector3, world_scale: float) -> void:
	var radius := 0.1 * world_scale
	var height := 0.8 * world_scale
	add_block_cylinder(parent, pos + Vector3(0, height * 0.5, 0), radius, height)


static func add_block_cylinder(parent: Node3D, center: Vector3, radius: float, height: float) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	shape.shape = cyl
	body.add_child(shape)
	body.position = center
	parent.add_child(body)
