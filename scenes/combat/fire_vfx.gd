class_name FireVfx
extends RefCounted
## The look of fire: low-poly, flat-colored and a little jittery, so it sits with the faceted
## world instead of glowing like generic particles. The fireball is a cracked, molten rock in a
## faceted coma, with a crown of flame tongues around it (which reads from behind, where the
## camera sees it) and chunky diamond embers instead of soft sprites. Colors run through the
## whole fire palette (gold, orange, crimson, with a touch of magenta at the tips) instead of staying one shade of red.

const HORN := preload("res://assets/shaders/fire_horn.gdshader")

const HOT := Color(1.0, 0.9, 0.45)
const MID := Color(1.0, 0.45, 0.04)
const COOL := Color(0.92, 0.1, 0.12)
const PINK := Color(0.82, 0.08, 0.52)
const VIOLET := Color(0.42, 0.18, 0.9)
const ASH := Color(0.33, 0.2, 0.22)
const SMOKE := Color(0.46, 0.38, 0.5)
const HORNS := 26


## The fireball: no solid body, just a dense bundle of plasma tongues streaming back along +Z.
static func fireball_body() -> Node3D:
	var body := Node3D.new()
	body.add_child(_horns())
	return body


## Embers and smoke shed along the way, left in world space so they hang behind the fireball.
static func fireball_trail() -> Array[GPUParticles3D]:
	var embers := _chunks(0.22, 36, 0.6, 0.09, Vector2(0.2, 1.0), 180.0, Vector3(0.0, 1.2, 0.0))
	var smoke := _smoke(0.15, 6, 0.8, 0.25, Vector2(0.1, 0.4), Vector3(0.0, 0.8, 0.0))
	return [embers, smoke]


## Embers drifting up from something that is burning.
static func flames(radius: float, amount: int, lifetime: float, size: float) -> GPUParticles3D:
	return _chunks(radius, amount, lifetime, size, Vector2(0.3, 1.0), 25.0, Vector3(0.0, 2.2, 0.0))


## Crown of flame tongues around the flight axis, each leaning outward and back.
static func _horns() -> MultiMeshInstance3D:
	return Vfx.crown(_tongue(0.0, 0.32, 0.3), HORNS)


## One tongue of plasma flame, a unit cone pointing up (+Y).
static func _tongue(bias := 0.0, girth := 0.26, sway := 0.25) -> CylinderMesh:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = girth
	cone.height = 2.6
	cone.radial_segments = 6
	cone.rings = 1
	cone.cap_top = false
	cone.cap_bottom = false
	var material := ShaderMaterial.new()
	material.shader = HORN
	material.set_shader_parameter("bias", bias)
	material.set_shader_parameter("sway", sway)
	cone.material = material
	return cone


## Flames standing upright at the given points (relative to the node), each with its own
## height and girth. Used for patches of burning ground.
static func flame_field(points: PackedVector3Array, tallest: float, seed_value := 3) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = _tongue(0.0, 0.45, 0.5)
	multi.instance_count = points.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in points.size():
		var height := rng.randf_range(0.4, 1.0) * tallest / 2.6
		var girth := rng.randf_range(0.8, 1.5)
		var lean := Basis(Vector3.RIGHT, rng.randf_range(-0.2, 0.2)) * Basis(Vector3.BACK, rng.randf_range(-0.2, 0.2))
		var basis := lean * Basis.from_scale(Vector3(girth, height, girth))
		# The cone is centered on its origin, so lift it by half its height to stand on the point.
		multi.set_instance_transform(i, Transform3D(basis, points[i] + Vector3.UP * (1.3 * height)))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multi
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


## Chunky diamonds that run through the fire colors and shrink away.
static func _chunks(
	radius: float, amount: int, lifetime: float, size: float, speed: Vector2, spread: float, gravity: Vector3,
) -> GPUParticles3D:
	var process := _scatter(radius, speed, spread, gravity)
	process.scale_min = 0.6
	process.scale_max = 1.2
	process.scale_curve = Vfx.shrink_curve()
	process.angular_velocity_min = -200.0
	process.angular_velocity_max = 200.0
	process.color_ramp = Vfx.ramp([HOT, MID, COOL, ASH])
	return _emitter(process, _diamond(size), amount, lifetime)


## Dull low-poly puffs that swell, drift up and vanish.
static func _smoke(
	radius: float, amount: int, lifetime: float, size: float, speed: Vector2, gravity: Vector3,
) -> GPUParticles3D:
	var process := _scatter(radius, speed, 180.0, gravity)
	process.scale_min = 0.7
	process.scale_max = 1.3
	process.scale_curve = Vfx.puff_curve()
	process.color_ramp = Vfx.ramp([SMOKE, SMOKE.darkened(0.25)])
	return _emitter(process, _ball(size * 0.5, 6, 3), amount, lifetime)


static func _scatter(radius: float, speed: Vector2, spread: float, gravity: Vector3) -> ParticleProcessMaterial:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = radius
	process.direction = Vector3.UP
	process.spread = spread
	process.initial_velocity_min = speed.x
	process.initial_velocity_max = speed.y
	process.gravity = gravity
	return process


static func _emitter(process: ParticleProcessMaterial, mesh: Mesh, amount: int, lifetime: float) -> GPUParticles3D:
	var emitter := Vfx.particles(process, mesh, amount, lifetime)
	emitter.local_coords = false
	emitter.fixed_fps = 60
	return emitter


## Flat-colored vertex-tinted material, so particle colors show without any lighting.
static func _flat(color := Color.WHITE) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	material.vertex_color_use_as_albedo = true
	return material


static func _diamond(size: float) -> SphereMesh:
	var mesh := _ball(size * 0.5, 4, 2)
	mesh.height = size * 1.7
	return mesh


static func _ball(radius: float, segments: int, rings: int) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = rings
	mesh.material = _flat()
	return mesh


static func _solid(mesh: Mesh, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance
