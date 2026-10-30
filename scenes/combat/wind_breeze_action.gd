class_name WindBreezeAction
extends AbilityAction
## Breeze cloak: wraps the hero in a light wind for a while. Footsteps nearly vanish, so foes hear
## far less of them, and the hero walks and runs faster.

const DURATION := 12.0

var _aura: GPUParticles3D


func _ready() -> void:
	_aura = _make_aura()
	add_child(_aura)


func _cast() -> bool:
	caster.breeze_left = DURATION
	return true


func _update(_delta: float) -> void:
	_aura.global_position = caster.global_position + Vector3.UP * 0.4
	_aura.emitting = caster.breeze_left > 0.0


## Pale flecks rising in a ring around the hero.
func _make_aura() -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	process.emission_ring_axis = Vector3.UP
	process.emission_ring_radius = 0.9
	process.emission_ring_inner_radius = 0.6
	process.emission_ring_height = 0.2
	process.direction = Vector3.UP
	process.spread = 12.0
	process.initial_velocity_min = 1.0
	process.initial_velocity_max = 2.2
	process.gravity = Vector3.ZERO
	process.scale_min = 0.4
	process.scale_max = 0.9
	process.color_ramp = Vfx.ramp([Color(0.9, 1.0, 0.95, 0.0), Color(0.75, 1.0, 0.9, 0.8), Color(0.5, 0.92, 0.76, 0.0)])
	var emitter := Vfx.particles(process, Vfx.soft_quad(0.3), 36, 1.0)
	emitter.local_coords = false
	emitter.top_level = true
	emitter.emitting = false
	return emitter
