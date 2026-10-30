class_name LightCharge
extends Node3D
## Energy gathering in a ball of light for the light cannon: motes of light are pulled in
## from a wide sphere, a ball of light swells where they meet and turns white-hot, and a glow
## lights the hero's surroundings more and more. [method set_charge] drives it from 0 to 1;
## the owner moves the node to where the energy gathers every frame.

const GOLD := Color(1.0, 0.8, 0.3)
const REACH := 3.2  # how far out the motes start
const PULL_TIME := 0.55
const MAX_ORB := 0.75
const MAX_LIGHT := 3.2

var _orb := MeshInstance3D.new()
var _orb_material := StandardMaterial3D.new()
var _motes: GPUParticles3D
var _light := OmniLight3D.new()
var _charge := 0.0


func _ready() -> void:
	_orb_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_orb_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_orb_material.albedo_color = GOLD
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 14
	sphere.rings = 8
	sphere.material = _orb_material
	_orb.mesh = sphere
	_orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_orb)

	_motes = _make_motes()
	add_child(_motes)

	_light.light_color = Color(1.0, 0.9, 0.6)
	_light.omni_range = 9.0
	_light.omni_attenuation = 0.9
	_light.light_energy = 0.0
	add_child(_light)
	set_charge(0.0)


## 0 is nothing yet, 1 is fully charged.
func set_charge(value: float) -> void:
	_charge = clampf(value, 0.0, 1.0)
	var swell := _charge * _charge
	var size := MAX_ORB * swell * randf_range(0.92, 1.0)
	_orb.scale = Vector3.ONE * maxf(size, 0.001)
	_orb_material.albedo_color = GOLD.lerp(Color(1.0, 1.0, 0.9), _charge) * (0.8 + _charge)
	_light.light_energy = MAX_LIGHT * swell * randf_range(0.85, 1.0)
	_motes.amount_ratio = clampf(0.15 + _charge, 0.0, 1.0)
	_motes.emitting = _charge > 0.0


func _make_motes() -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
	process.emission_sphere_radius = REACH
	process.initial_velocity_min = 0.0
	process.initial_velocity_max = 0.0
	# From rest, falling straight in: distance = acceleration * time^2 / 2, so this arrives on time.
	process.gravity = Vector3.ZERO
	var pull := 2.0 * REACH / (PULL_TIME * PULL_TIME)
	process.radial_accel_min = -pull
	process.radial_accel_max = -pull
	process.scale_min = 0.7
	process.scale_max = 1.5
	process.color_ramp = Vfx.ramp([Color(GOLD * 2.2, 0.0), Color(GOLD * 2.2, 1.0), Color(2.2, 2.2, 1.9, 1.0)])
	process.scale_curve = _grow_in()
	var emitter := Vfx.particles(process, Vfx.soft_quad(0.36), 180, PULL_TIME)
	emitter.local_coords = true
	emitter.emitting = false
	return emitter


## Small when far out and bigger as it nears the center.
func _grow_in() -> CurveTexture:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.3))
	curve.add_point(Vector2(1.0, 1.0))
	var texture := CurveTexture.new()
	texture.curve = curve
	return texture
