class_name Vfx
extends RefCounted
## Particle helpers the spells share: additive glow quads, color ramps, sparks and glints.

static var _glow: ImageTexture


## Soft round blob, opaque white in the middle and clear at the edge.
static func glow_texture() -> ImageTexture:
	if _glow:
		return _glow
	var size := 64
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var p := (Vector2(x, y) + Vector2.ONE * 0.5) / size * 2.0 - Vector2.ONE
			var v := pow(clampf(1.0 - p.length(), 0.0, 1.0), 1.6)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, v))
	_glow = ImageTexture.create_from_image(image)
	return _glow


static func glow_quad(size: float) -> QuadMesh:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = glow_texture()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	quad.material = material
	return quad


## Colors spread evenly over a particle's life.
static func ramp(colors: Array[Color]) -> GradientTexture1D:
	var gradient := Gradient.new()
	var offsets := PackedFloat32Array()
	for i in colors.size():
		offsets.append(float(i) / float(colors.size() - 1))
	gradient.offsets = offsets
	gradient.colors = PackedColorArray(colors)
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture


## Swells quickly, then shrinks to nothing.
static func puff_curve() -> CurveTexture:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.5))
	curve.add_point(Vector2(0.25, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	var texture := CurveTexture.new()
	texture.curve = curve
	return texture


static func particles(process: ParticleProcessMaterial, mesh: Mesh, amount: int, lifetime: float) -> GPUParticles3D:
	var emitter := GPUParticles3D.new()
	emitter.amount = amount
	emitter.lifetime = lifetime
	emitter.draw_pass_1 = mesh
	emitter.process_material = process
	emitter.visibility_aabb = AABB(Vector3(-6, -6, -6), Vector3(12, 12, 12))
	return emitter


## Quick spray of sparks where something was hit.
static func sparks(parent: Node, at: Vector3, color: Color, amount := 10) -> void:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.05
	process.direction = Vector3.UP
	process.spread = 180.0
	process.initial_velocity_min = 2.0
	process.initial_velocity_max = 6.0
	process.gravity = Vector3(0.0, -7.0, 0.0)
	process.scale_min = 0.5
	process.scale_max = 1.0
	process.color_ramp = ramp([Color(1, 1, 1, 1), color, Color(color, 0.0)])
	var emitter := particles(process, glow_quad(0.28), amount, 0.35)
	emitter.one_shot = true
	emitter.explosiveness = 1.0
	emitter.finished.connect(emitter.queue_free)
	parent.add_child(emitter)
	emitter.global_position = at
	emitter.emitting = true


## Cloud of tiny flat-colored diamonds scattered along a line (the emitter's +Z, [param length]
## long), drifting off and shrinking away. Left in world space, so they trail behind a mover.
static func motes(color: Color, amount: int, lifetime: float, length: float, spread: float) -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(spread, spread, length * 0.5)
	process.direction = Vector3.UP
	process.spread = 180.0
	process.initial_velocity_min = 0.1
	process.initial_velocity_max = 0.6
	process.gravity = Vector3.ZERO
	process.scale_min = 0.5
	process.scale_max = 1.1
	process.scale_curve = shrink_curve()
	process.angular_velocity_min = -240.0
	process.angular_velocity_max = 240.0
	process.color_ramp = ramp([Color(1, 1, 1, 1), color, Color(color, 0.0)])

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	var diamond := SphereMesh.new()
	diamond.radius = 0.03
	diamond.height = 0.1
	diamond.radial_segments = 4
	diamond.rings = 2
	diamond.material = material
	var emitter := particles(process, diamond, amount, lifetime)
	emitter.local_coords = false
	return emitter


## Grows then drops to nothing, hard at the end: debris that burns out.
static func shrink_curve() -> CurveTexture:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(0.6, 0.7))
	curve.add_point(Vector2(1.0, 0.0))
	var texture := CurveTexture.new()
	texture.curve = curve
	return texture
