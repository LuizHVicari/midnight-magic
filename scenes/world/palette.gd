class_name Palette
extends RefCounted
## Recolors the Kenney Nature Kit. Its colors are very light pastels (leaves a near-white teal,
## trunks a pale salmon, rocks an icy white), which light turns into a washed-out world. This
## maps them to a more natural, deeper set: green leaves and grass, brown wood, grey stone.
## Each flat color of a model's materials is recolored once, so the change is global and free at
## runtime. Flip [constant ENABLED] to get the original look back. Textured materials (the
## Survival and Town kits) are left alone.

const ENABLED := true

const LEAF_HUE := 0.29  # where teal leaves land: a fresh green
const LEAF_VALUE := 0.74  # and how much darker they get
const WOOD_HUE := 0.075
const WOOD_VALUE := 0.5
const STONE_VALUE := 0.7

static var _meshes := {}  # instance id of a mesh -> true, so each is recolored once
static var _materials := {}  # original material -> recolored copy


static func recolor_node(root: Node) -> void:
	if not ENABLED:
		return
	for mesh_node: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		recolor_mesh(mesh_node.mesh)


static func recolor_mesh(mesh: Mesh) -> void:
	if not ENABLED or mesh == null or _meshes.has(mesh.get_instance_id()):
		return
	_meshes[mesh.get_instance_id()] = true
	for surface in mesh.get_surface_count():
		var original := mesh.surface_get_material(surface)
		var recolored := _recolored(original)
		if recolored != original:
			mesh.surface_set_material(surface, recolored)


## The color after remapping. Hues that are not leaves, wood or stone come back as they were.
static func natural(color: Color) -> Color:
	if _is_leaf(color):
		return Color.from_hsv(LEAF_HUE + (color.h - 0.48) * 1.2, minf(color.s + 0.02, 1.0), color.v * LEAF_VALUE)
	if _is_stone(color):
		return Color.from_hsv(0.58, 0.05, color.v * STONE_VALUE)
	if _is_wood(color):
		return Color.from_hsv(WOOD_HUE, minf(color.s + 0.22, 1.0), color.v * WOOD_VALUE)
	return color


static func _is_leaf(color: Color) -> bool:
	return color.h > 0.43 and color.h < 0.52 and color.s > 0.3


static func _is_stone(color: Color) -> bool:
	return color.h > 0.48 and color.h < 0.56 and color.s < 0.2 and color.v < 0.99


static func _is_wood(color: Color) -> bool:
	return color.h > 0.03 and color.h < 0.095 and color.s >= 0.28


static func _recolored(material: Material) -> Material:
	var base := material as BaseMaterial3D
	if base == null or base.albedo_texture != null:
		return material
	if _materials.has(material):
		return _materials[material]
	var copy := base.duplicate() as BaseMaterial3D
	copy.albedo_color = natural(base.albedo_color)
	_materials[material] = copy
	return copy
