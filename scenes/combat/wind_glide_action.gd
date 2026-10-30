class_name WindGlideAction
extends AbilityAction
## Glide: held in the air, the hero stops falling and drifts forward on the wind, leaning into
## it. It drinks a little mana for as long as it lasts, and ends when the button is let go, the
## mana runs out or the hero lands.

const DRAIN := 4.0  # mana per second

var _trail: GPUParticles3D
var _stars: GPUParticles3D


func _ready() -> void:
	_trail = _make_trail()
	add_child(_trail)
	_stars = Vfx.sparkles(0.5, 0.8, 50, 0.9, 0.22, Color(0.6, 1.0, 0.85), 0.3)
	_stars.emitting = false
	_stars.top_level = true
	add_child(_stars)


func _cast() -> bool:
	return caster.begin_glide()


func release() -> void:
	caster.end_glide()


func _update(delta: float) -> void:
	_trail.global_position = caster.global_position + Vector3.UP * 1.0
	_trail.emitting = caster.gliding
	_stars.global_position = caster.global_position + Vector3.UP * 0.3
	_stars.emitting = caster.gliding
	if caster.gliding and not caster.spend_mana(DRAIN * delta):
		caster.end_glide()


## Flecks of wind left hanging behind the hero as they pass.
func _make_trail() -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.5
	process.direction = Vector3.UP
	process.spread = 180.0
	process.initial_velocity_min = 0.1
	process.initial_velocity_max = 0.6
	process.gravity = Vector3.ZERO
	process.scale_min = 0.5
	process.scale_max = 1.2
	process.color_ramp = Vfx.ramp([Color(0.9, 1.0, 0.95, 0.9), Color(0.5, 0.92, 0.76, 0.0)])
	var emitter := Vfx.particles(process, Vfx.soft_quad(0.35), 40, 0.6)
	emitter.local_coords = false
	emitter.top_level = true
	emitter.emitting = false
	return emitter
