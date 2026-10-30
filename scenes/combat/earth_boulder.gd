class_name EarthBoulder
extends Node3D
## A great rock thrown in an arc. Where it lands it hits hard in a wide circle, stuns and shoves
## everything there, leaves rubble behind as cover and shakes the ground.

const GRAVITY := 22.0
const RADIUS := 4.5
const DAMAGE := 95.0
const EDGE := 0.4  # share of the damage left at the rim
const STUN := 1.6
const SHOVE := 8.0
const RUBBLE := 4
const SPIN := 5.0
const SHAKE_REACH := 35.0

var element: Element
var caster: Player
var velocity := Vector3.ZERO

var _rock := MeshInstance3D.new()
var _age := 0.0


func _ready() -> void:
	_rock.mesh = EarthVfx.rock_mesh(0.85, 7)
	_rock.material_override = EarthVfx.spike_material()
	add_child(_rock)
	add_child(_trail())


func _physics_process(delta: float) -> void:
	_age += delta
	velocity.y -= GRAVITY * delta
	_rock.rotate_x(SPIN * delta)
	_rock.rotate_z(SPIN * 0.7 * delta)
	var from := global_position
	var to := from + velocity * delta
	var hit := Combat.raycast(self, from, to, [caster.get_rid()])
	if hit.is_empty() and _age < 5.0:
		global_position = to
		return
	_land(hit["position"] if not hit.is_empty() else to)


func _land(at: Vector3) -> void:
	var parent := get_parent()
	var exclude := StoneBlock.bodies(get_tree())
	exclude.append(caster.get_rid())
	var struck := Combat.blast(self, at + Vector3.UP * 0.4, RADIUS, DAMAGE, element, exclude, EDGE)
	for health in struck:
		health.stun(STUN, element)
		var away := health.focus_point() - at
		away.y = 0.0
		health.push((away.normalized() + Vector3.UP * 0.4) * SHOVE)
	EarthVfx.dust(parent, at, RADIUS * 0.9)
	EarthVfx.dust(parent, at + Vector3.UP * 0.4, RADIUS * 0.6)
	Vfx.sparks(parent, at + Vector3.UP * 0.5, EarthVfx.TIP, 26)
	Vfx.flash(parent, at + Vector3.UP * 1.0, Color(1.0, 0.75, 0.4), 6.0, 14.0, 0.3)
	_rubble(parent, at)
	var away := caster.global_position.distance_to(at)
	if away < SHAKE_REACH:
		caster.shake(lerpf(0.35, 0.08, away / SHAKE_REACH))
	queue_free()


## A few chunks of the rock stay behind as cover.
func _rubble(parent: Node, at: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in RUBBLE:
		var turn := rng.randf() * TAU
		var spot := at + Vector3(cos(turn), 0.0, sin(turn)) * rng.randf_range(1.6, RADIUS * 0.75)
		var ground := Combat.raycast(self, spot + Vector3.UP * 6.0, spot + Vector3.DOWN * 12.0)
		var chunk := StoneBlock.new()
		var width := rng.randf_range(0.9, 1.5)
		chunk.size = Vector3(width, rng.randf_range(0.7, 1.2), width)
		chunk.hit_points = 20.0
		chunk.life = 12.0
		chunk.seed_value = rng.randi()
		chunk.rotation.y = rng.randf() * TAU
		chunk.position = ground["position"] if not ground.is_empty() else spot
		parent.add_child(chunk)


## A tail of dust and tumbling grit behind the rock.
func _trail() -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.5
	process.direction = Vector3.UP
	process.spread = 180.0
	process.initial_velocity_min = 0.3
	process.initial_velocity_max = 1.4
	process.gravity = Vector3(0.0, -2.0, 0.0)
	process.scale_min = 0.6
	process.scale_max = 1.3
	process.scale_curve = Vfx.puff_curve()
	process.color_ramp = Vfx.ramp([Color(EarthVfx.DUST, 0.7), Color(EarthVfx.DUST, 0.4), Color(EarthVfx.DUST, 0.0)])
	var emitter := Vfx.particles(process, Vfx.alpha_quad(1.1), 50, 0.8)
	emitter.local_coords = false
	emitter.emitting = true
	return emitter
