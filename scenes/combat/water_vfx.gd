class_name WaterVfx
extends RefCounted
## The look of water: a hard jet of streaked droplets that arc a little under gravity, from
## white-hot foam at the wand through bright aqua to deep blue, with splashes where it lands.
## Droplets are stretched low-poly spindles aligned to their own motion, so each one reads as a
## streak of water.

const FOAM := Color(0.5, 0.86, 1.0)
const AQUA := Color(0.08, 0.48, 1.0)
const BLUE := Color(0.05, 0.24, 0.82)
const DEEP := Color(0.06, 0.2, 0.7)


## The jet. Its -Z is the way the water flies; the caller points it. Left in world space so
## droplets keep their path when the hero turns.
static func jet(speed: float, lifetime: float, amount: int) -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.12
	process.direction = Vector3(0.0, 0.0, -1.0)
	process.spread = 3.5
	process.initial_velocity_min = speed * 0.9
	process.initial_velocity_max = speed * 1.05
	process.gravity = Vector3(0.0, -5.0, 0.0)
	process.particle_flag_align_y = true
	process.scale_min = 0.6
	process.scale_max = 1.1
	process.scale_curve = _thin_out()
	process.color_ramp = Vfx.ramp([FOAM, AQUA, BLUE, Color(DEEP, 0.0)])
	var emitter := Vfx.particles(process, _droplet(0.9), amount, lifetime)
	emitter.local_coords = false
	return emitter


## Water thrown up where the jet hits something, falling back down.
static func splash() -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.2
	process.direction = Vector3.UP
	process.spread = 55.0
	process.initial_velocity_min = 2.5
	process.initial_velocity_max = 6.0
	process.gravity = Vector3(0.0, -14.0, 0.0)
	process.particle_flag_align_y = true
	process.scale_min = 0.5
	process.scale_max = 1.1
	process.scale_curve = _thin_out()
	process.color_ramp = Vfx.ramp([FOAM, AQUA, Color(BLUE, 0.0)])
	var emitter := Vfx.particles(process, _droplet(0.5), 26, 0.55)
	emitter.local_coords = false
	emitter.emitting = false
	return emitter


## Drips and mist hanging round something soaked, falling away.
static func wet_aura() -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.5
	process.direction = Vector3.DOWN
	process.spread = 25.0
	process.initial_velocity_min = 0.2
	process.initial_velocity_max = 0.8
	process.gravity = Vector3(0.0, -6.0, 0.0)
	process.particle_flag_align_y = true
	process.scale_min = 0.5
	process.scale_max = 1.0
	process.scale_curve = _thin_out()
	process.color_ramp = Vfx.ramp([AQUA, BLUE, Color(BLUE, 0.0)])
	var aura := Vfx.particles(process, _droplet(0.4), 22, 0.7)
	aura.local_coords = false
	aura.emitting = false
	return aura


## A spindle: a four-sided low-poly drop stretched along Y (which the particle aligns to its
## velocity), flat colored by the particle color.
static func _droplet(length: float) -> SphereMesh:
	var mesh := Vfx.diamond_mesh(0.055)
	mesh.height = 0.2 * length * 4.0
	return mesh


## Full size for most of its life, then thins to nothing.
static func _thin_out() -> CurveTexture:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(0.7, 0.9))
	curve.add_point(Vector2(1.0, 0.0))
	var texture := CurveTexture.new()
	texture.curve = curve
	return texture
