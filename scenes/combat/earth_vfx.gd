class_name EarthVfx
extends RefCounted
## The look of earth: chunky faceted stone in ochre, terracotta and sand, with flat dust puffs and
## tumbling pebbles. Warm and heavy, against the cool pastels of the rest of the world.

const BASE := Color(0.5, 0.28, 0.24)
const MID := Color(0.78, 0.5, 0.3)
const TIP := Color(0.95, 0.82, 0.58)
const DUST := Color(0.82, 0.68, 0.48)
const PEBBLE := Color(0.5, 0.34, 0.26)
const AMBER := Color(1.0, 0.7, 0.2)

static var _spikes: Array[ArrayMesh] = []


## A faceted, slightly crooked stone spike about 2.2 m tall, three shared variants. Flat
## shaded, with the colors baked into the vertices: terracotta at the root to sand at the tip.
static func spike_mesh(variant: int) -> ArrayMesh:
	if _spikes.is_empty():
		for i in 3:
			_spikes.append(_build_spike(i * 17 + 3))
	return _spikes[variant % _spikes.size()]


static func spike_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


## Puff of dust and a spray of pebbles where stone breaks the ground. One shot, frees itself.
static func dust(parent: Node, at: Vector3, size: float) -> void:
	var puff_process := ParticleProcessMaterial.new()
	puff_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	puff_process.emission_sphere_radius = size * 0.4
	puff_process.direction = Vector3.UP
	puff_process.spread = 70.0
	puff_process.initial_velocity_min = 0.6
	puff_process.initial_velocity_max = 2.2
	puff_process.gravity = Vector3(0.0, -1.0, 0.0)
	puff_process.scale_min = 0.7
	puff_process.scale_max = 1.3
	puff_process.scale_curve = Vfx.puff_curve()
	puff_process.color_ramp = Vfx.ramp([Color(DUST, 0.75), Color(DUST, 0.45), Color(DUST, 0.0)])
	var puff_material := StandardMaterial3D.new()
	puff_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	puff_material.vertex_color_use_as_albedo = true
	var puff := SphereMesh.new()
	puff.radius = size * 0.5
	puff.height = size
	puff.radial_segments = 6
	puff.rings = 3
	puff.material = puff_material
	var cloud := Vfx.particles(puff_process, puff, 7, 0.9)

	var chip_process := ParticleProcessMaterial.new()
	chip_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	chip_process.emission_sphere_radius = size * 0.3
	chip_process.direction = Vector3.UP
	chip_process.spread = 50.0
	chip_process.initial_velocity_min = 3.0
	chip_process.initial_velocity_max = 7.0
	chip_process.gravity = Vector3(0.0, -16.0, 0.0)
	chip_process.scale_min = 0.6
	chip_process.scale_max = 1.5
	chip_process.scale_curve = Vfx.shrink_curve()
	chip_process.angular_velocity_min = -400.0
	chip_process.angular_velocity_max = 400.0
	chip_process.color_ramp = Vfx.ramp([TIP, PEBBLE, Color(PEBBLE, 0.0)])
	var chips := Vfx.particles(chip_process, Vfx.diamond_mesh(0.07), 12, 0.7)

	for emitter: GPUParticles3D in [cloud, chips]:
		emitter.one_shot = true
		emitter.explosiveness = 0.9
		emitter.local_coords = false
		emitter.finished.connect(emitter.queue_free)
		parent.add_child(emitter)
		emitter.global_position = at
		emitter.emitting = true


## Little stones circling something stunned. Turn it on while the stun lasts.
static func stun_halo() -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	process.emission_ring_axis = Vector3.UP
	process.emission_ring_radius = 0.55
	process.emission_ring_inner_radius = 0.5
	process.emission_ring_height = 0.05
	process.direction = Vector3.ZERO
	process.initial_velocity_min = 0.0
	process.initial_velocity_max = 0.0
	process.gravity = Vector3.ZERO
	process.orbit_velocity_min = 0.9
	process.orbit_velocity_max = 1.1
	process.scale_min = 1.0
	process.scale_max = 1.6
	process.color_ramp = Vfx.ramp([AMBER, TIP, Color(AMBER, 0.6)])
	var halo := Vfx.particles(process, Vfx.diamond_mesh(0.07), 6, 1.0)
	halo.local_coords = true
	halo.emitting = false
	return halo


static func _build_spike(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var sides := 5
	var height := 2.2
	var mid_height := rng.randf_range(0.7, 0.95)
	var tip := Vector3(rng.randf_range(-0.2, 0.2), height, rng.randf_range(-0.2, 0.2))
	var base: Array[Vector3] = []
	var mid: Array[Vector3] = []
	for j in sides:
		var angle := TAU * j / sides + rng.randf_range(-0.2, 0.2)
		base.append(Vector3(cos(angle), 0.0, sin(angle)) * rng.randf_range(0.5, 0.68))
		mid.append(Vector3(cos(angle + 0.3), mid_height, sin(angle + 0.3)) * rng.randf_range(0.28, 0.4) + Vector3(tip.x * 0.3, 0.0, tip.z * 0.3))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for j in sides:
		var k := (j + 1) % sides
		_tri(st, base[j], mid[j], base[k], BASE, MID, BASE)
		_tri(st, base[k], mid[j], mid[k], BASE, MID, MID)
		_tri(st, mid[j], tip, mid[k], MID, TIP, MID)
	st.generate_normals()
	return st.commit()


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	# Vertex colors are linear, the palette constants are sRGB.
	st.set_color(ca.srgb_to_linear())
	st.add_vertex(a)
	st.set_color(cb.srgb_to_linear())
	st.add_vertex(b)
	st.set_color(cc.srgb_to_linear())
	st.add_vertex(c)
