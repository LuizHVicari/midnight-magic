class_name ShadowVfx
extends RefCounted
## The look of shadow: near-black violet smoke that flows into bright magenta edges. It is the
## dark counterpart of everything else in this bright pastel world, so it reads by contrast.
## Tendrils of smoke are shader-driven; flecks are flat diamonds like the rest of the effects.

const TONGUE := preload("res://assets/shaders/shadow_tongue.gdshader")

const DEEP := Color(0.03, 0.0, 0.07)
const VIOLET := Color(0.22, 0.05, 0.4)
const GLOW := Color(0.62, 0.22, 0.85)
const TENDRILS := 20


## The wisp: a dense bundle of tendrils streaming back along +Z.
static func wisp_body() -> Node3D:
	var body := Node3D.new()
	body.add_child(Vfx.crown(_tendril(0.3, 0.3), TENDRILS, 11, Vector2(3.0, 26.0), Vector2(0.5, 1.2)))
	return body


## Flecks of darkness shed along the way, left in world space.
static func wisp_trail() -> Array[GPUParticles3D]:
	return [Vfx.motes(DEEP, 30, 0.7, 0.5, 0.15, GLOW), smoke(0.15, 9, 0.8, 0.3)]


## Dark low-poly smoke puffs that swell, drift up and thin out; left in world space.
static func smoke(radius: float, amount: int, lifetime: float, size: float) -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = radius
	process.direction = Vector3.UP
	process.spread = 60.0
	process.initial_velocity_min = 0.2
	process.initial_velocity_max = 0.8
	process.gravity = Vector3(0.0, 0.5, 0.0)
	process.scale_min = 0.7
	process.scale_max = 1.3
	process.scale_curve = Vfx.puff_curve()
	process.color_ramp = Vfx.ramp([Color(0.1, 0.02, 0.2, 0.55), Color(0.03, 0.0, 0.07, 0.5), Color(0.03, 0.0, 0.07, 0.0)])
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	var puff := SphereMesh.new()
	puff.radius = size * 0.5
	puff.height = size
	puff.radial_segments = 6
	puff.rings = 3
	puff.material = material
	var emitter := Vfx.particles(process, puff, amount, lifetime)
	emitter.local_coords = false
	return emitter


## Darkness bleeding off a cursed target, rising and fading. Turn it on while the curse lasts.
static func curse_aura() -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.55
	process.direction = Vector3.UP
	process.spread = 30.0
	process.initial_velocity_min = 0.5
	process.initial_velocity_max = 1.3
	process.gravity = Vector3.ZERO
	process.scale_min = 0.6
	process.scale_max = 1.5
	process.scale_curve = Vfx.shrink_curve()
	process.angular_velocity_min = -200.0
	process.angular_velocity_max = 200.0
	process.color_ramp = Vfx.ramp([VIOLET, DEEP, Color(DEEP, 0.0)])
	var aura := Vfx.particles(process, Vfx.diamond_mesh(0.08), 30, 1.1)
	aura.local_coords = false
	aura.emitting = false
	return aura


## Burst of dark flecks where a wisp lands.
static func impact(parent: Node, at: Vector3) -> void:
	var puffs := smoke(0.2, 7, 0.8, 0.4)
	puffs.one_shot = true
	puffs.explosiveness = 1.0
	puffs.finished.connect(puffs.queue_free)
	parent.add_child(puffs)
	puffs.global_position = at
	puffs.emitting = true

	var burst := Vfx.motes(DEEP, 18, 0.6, 0.1, 0.1, GLOW)
	var process := burst.process_material as ParticleProcessMaterial
	process.initial_velocity_min = 2.0
	process.initial_velocity_max = 5.5
	process.damping_min = 4.0
	process.damping_max = 6.0
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.finished.connect(burst.queue_free)
	parent.add_child(burst)
	burst.global_position = at
	burst.emitting = true


static func _tendril(girth: float, sway: float) -> CylinderMesh:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = girth
	cone.height = 2.4
	cone.radial_segments = 6
	cone.rings = 1
	cone.cap_top = false
	cone.cap_bottom = false
	var material := ShaderMaterial.new()
	material.shader = TONGUE
	material.set_shader_parameter("sway", sway)
	cone.material = material
	return cone
