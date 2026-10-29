class_name WaterAttack
extends SpellAttack
## Water: a pressurised jet while the button is held. Pressure builds the longer it is held:
## the jet gets harder, longer, wider and starts shoving what it hits, but it also drinks more
## mana. It soaks everything it touches (slowing it, putting out fire, and making it take extra
## damage from light), so it is the opener that sets up the other elements.

const RAMP_TIME := 2.2  # seconds to full pressure
const REACH := Vector2(15.0, 24.0)  # at no pressure, at full
const HALF_ANGLE := Vector2(3.0, 6.5)
const BASE_RADIUS := 0.8  # how wide the beam is at the wand, so close targets still get hit
const DPS := Vector2(16.0, 62.0)
const PUSH := Vector2(0.0, 7.0)  # m/s of shove per tick at no pressure, at full
const MANA_PER_SECOND := Vector2(10.0, 20.0)
const MIN_MANA := 4.0  # needed to start squirting
const TICK := 0.1
const SLOW := 0.55  # speed left while soaked
const SLOW_TIME := 1.4
const AMOUNT := Vector2(160.0, 420.0)
const SIZE := Vector2(0.7, 1.6)

var _holding := false
var _held := 0.0
var _tick := 0.0
var _jet: GPUParticles3D
var _splash: GPUParticles3D


func _ready() -> void:
	_jet = WaterVfx.jet(30.0, REACH.y / 30.0 + 0.1, int(AMOUNT.y))
	_splash = WaterVfx.splash()
	# World-space emitters live in the world, not under the hero.
	_jet.top_level = true
	_splash.top_level = true
	add_child(_jet)
	add_child(_splash)


func begin() -> void:
	if caster.mana < MIN_MANA or not caster.begin_cast(Player.ANIM_CHANNEL, INF, 1.6, Player.CHANNEL_HOLD):
		return
	_holding = true
	_held = 0.0
	_tick = 0.0
	_jet.emitting = true


func release() -> void:
	if not _holding:
		return
	_stop()
	caster.end_cast()


func _stop() -> void:
	_holding = false
	_jet.emitting = false
	_splash.emitting = false


func _process(delta: float) -> void:
	if not _holding:
		return
	_held += delta
	var pressure := smoothstep(0.0, 1.0, _held / RAMP_TIME)
	if not caster.spend_mana(lerpf(MANA_PER_SECOND.x, MANA_PER_SECOND.y, pressure) * delta):
		_stop()
		caster.end_cast()
		return
	var reach := lerpf(REACH.x, REACH.y, pressure)
	var origin := caster.cast_origin()
	var aim := caster.aim_point(reach)
	var direction := (aim - origin).normalized()
	_shape_jet(pressure, reach)
	_jet.global_transform = Transform3D(Basis.looking_at(direction), origin)
	_splash.global_position = aim
	_splash.emitting = origin.distance_to(aim) < reach - 0.5

	_tick -= delta
	if _tick <= 0.0:
		_tick = TICK
		_soak(origin, direction, pressure, reach)


## More pressure: more droplets, thicker, faster and carrying the full reach.
func _shape_jet(pressure: float, reach: float) -> void:
	var process := _jet.process_material as ParticleProcessMaterial
	var speed := reach / (_jet.lifetime - 0.1)
	process.initial_velocity_min = speed * 0.9
	process.initial_velocity_max = speed * 1.05
	process.scale_min = lerpf(SIZE.x, SIZE.y, pressure) * 0.8
	process.scale_max = lerpf(SIZE.x, SIZE.y, pressure) * 1.3
	process.spread = lerpf(2.5, 5.5, pressure)
	_jet.amount_ratio = lerpf(AMOUNT.x, AMOUNT.y, pressure) / AMOUNT.y


func _soak(origin: Vector3, direction: Vector3, pressure: float, reach: float) -> void:
	var angle := lerpf(HALF_ANGLE.x, HALF_ANGLE.y, pressure)
	for hit in Combat.in_beam(caster, origin, direction, reach, BASE_RADIUS, angle, [caster.get_rid()]):
		var health: Health = hit["health"]
		health.take_damage(lerpf(DPS.x, DPS.y, pressure) * TICK, element)
		health.slow(SLOW, SLOW_TIME)
		health.douse()
		var shove := lerpf(PUSH.x, PUSH.y, pressure)
		if shove > 0.5:
			health.push(direction * shove)
