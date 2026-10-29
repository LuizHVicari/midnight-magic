class_name WindVfx
extends RefCounted
## The look of wind: pale, minty spiral ribbons shooting away and widening, with tiny flat
## low-poly flecks swept along in swirls. Light colors on purpose, with a teal edge so the gust still
## reads against bright sky.

const STREAM := preload("res://assets/shaders/wind_stream.gdshader")

const PALE := Color(0.95, 1.0, 0.98)
const MINT := Color(0.5, 0.92, 0.76)
const TEAL := Color(0.12, 0.55, 0.62)


## Spiral ribbons fanning out along -Z from the origin: [param count] strips that twist around
## the axis [param turns] times while widening to the cone's edge at [param reach]. One mesh, one
## material; the caller spins it and drives the "progress" shader parameter.
static func vortex(reach: float, half_angle_deg: float, count: int, turns := 0.8, segments := 28) -> MeshInstance3D:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var spread := tan(deg_to_rad(half_angle_deg)) * reach
	for k in count:
		var phase := TAU * k / count
		var direction := 1.0 if k % 2 == 0 else -1.0
		var reach_share := rng.randf_range(0.7, 1.0)
		var tag := Color(rng.randf(), 0.0, 0.0)
		var base := vertices.size()
		for i in segments + 1:
			var t := float(i) / segments
			var here := _spiral(t, phase, direction, turns, spread * reach_share, reach)
			var ahead := _spiral(minf(t + 0.02, 1.0), phase, direction, turns, spread * reach_share, reach)
			var tangent := (ahead - here).normalized()
			var outward := Vector3(here.x, here.y, 0.0).normalized()
			var side := tangent.cross(outward).normalized()
			var half_width := 0.1 + 0.42 * pow(sin(PI * t), 0.6) * reach / 14.0
			vertices.append(here - side * half_width)
			vertices.append(here + side * half_width)
			uvs.append(Vector2(t, 0.0))
			uvs.append(Vector2(t, 1.0))
			colors.append(tag)
			colors.append(tag)
		for i in segments:
			var v := base + i * 2
			indices.append_array([v, v + 1, v + 2, v + 1, v + 3, v + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := ShaderMaterial.new()
	material.shader = STREAM
	mesh.surface_set_material(0, material)
	mesh.custom_aabb = AABB(Vector3(-spread, -spread, -reach), Vector3(spread * 2.0, spread * 2.0, reach))
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


static func _spiral(t: float, phase: float, direction: float, turns: float, spread: float, reach: float) -> Vector3:
	var angle := phase + direction * t * turns * TAU
	var radius := 0.2 + spread * pow(t, 0.8)
	return Vector3(cos(angle) * radius, sin(angle) * radius, -t * reach)


## Leaves and flecks blown out along -Z and curling as they go.
static func swirl(reach: float, half_angle_deg: float, amount: int) -> GPUParticles3D:
	var speed := reach / 0.8
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.25
	process.direction = Vector3(0.0, 0.0, -1.0)
	process.spread = half_angle_deg
	process.initial_velocity_min = speed * 0.5
	process.initial_velocity_max = speed * 1.1
	process.gravity = Vector3.ZERO
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 2.2
	process.turbulence_noise_scale = 1.4
	process.turbulence_influence_min = 0.1
	process.turbulence_influence_max = 0.3
	process.scale_min = 0.8
	process.scale_max = 2.0
	process.scale_curve = Vfx.shrink_curve()
	process.angular_velocity_min = -520.0
	process.angular_velocity_max = 520.0
	process.color_ramp = Vfx.ramp([PALE, MINT, Color(TEAL, 0.0)])
	var emitter := Vfx.particles(process, Vfx.diamond_mesh(0.032), amount, 0.8)
	emitter.one_shot = true
	emitter.explosiveness = 0.55
	emitter.local_coords = false
	return emitter
