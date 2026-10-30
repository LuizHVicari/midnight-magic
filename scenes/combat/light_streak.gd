class_name LightStreak
extends RefCounted
## Building block of the light spells' look: one shaded layer of a streak of light.


## A cone or tapering shaft of [param length] starting [param start] behind the tip, wide at the
## tail end and narrowing to [param tip_radius] at the front. The tip is at the origin and the
## shaft trails along +Z. Layer a wide soft one under a thin hot one for a glowing needle.
static func layer(
	base_radius: float, tip_radius: float, length: float, start: float, color: Color,
	brightness: float, opacity: float, edge: float, tail: float, hot: float, tremble: float,
) -> MeshInstance3D:
	var cone := CylinderMesh.new()
	cone.top_radius = tip_radius
	cone.bottom_radius = base_radius
	cone.height = length
	cone.radial_segments = 12
	cone.cap_top = false
	cone.cap_bottom = false
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/light_lance.gdshader")
	material.set_shader_parameter("color", Vector3(color.r, color.g, color.b))
	material.set_shader_parameter("brightness", brightness)
	material.set_shader_parameter("opacity", opacity)
	material.set_shader_parameter("edge_power", edge)
	material.set_shader_parameter("tail_power", tail)
	material.set_shader_parameter("hot", hot)
	material.set_shader_parameter("tremble", tremble)
	material.set_shader_parameter("phase", randf() * TAU)
	var beam := MeshInstance3D.new()
	beam.mesh = cone
	beam.material_override = material
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The cylinder's top (+Y) is the front: turn it to -Z, with its front end [start] behind the tip.
	beam.rotation.x = -PI / 2.0
	beam.position.z = start + length * 0.5
	return beam


## Fades every layer under [param root] by [param value] (0 gone, 1 full).
static func set_fade(root: Node, value: float) -> void:
	for beam: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		(beam.material_override as ShaderMaterial).set_shader_parameter("fade", value)
