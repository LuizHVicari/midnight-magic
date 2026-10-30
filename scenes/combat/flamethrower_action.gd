class_name FlamethrowerAction
extends AbilityAction
## Flamethrower: a jet of fire from the wand for as long as the button is held. It hurts hard and
## sets alight everything in its short, narrow cone, drinking mana by the second. The wand heats up
## as it burns: hold it too long and it overheats and cannot be used for a few seconds, so it
## pays to fire in bursts. The slot shows the heat.

const REACH := 9.5
const HALF_ANGLE := 12.0
const BASE_RADIUS := 0.6
const TICK := 0.1
const DAMAGE := 5.5  # per tick up close
const FAR_SHARE := 0.5  # share of the damage left at the far end
const BURN_DPS := 5.0
const BURN_TIME := 3.0
const DRAIN := 14.0  # mana per second
const HEAT_PER_SECOND := 0.25  # four seconds of fire to overheat
const COOL_PER_SECOND := 0.4
const OVERHEAT_LOCK := 4.0
const JET_SPEED := 18.0
const LIGHT_COLOR := Color(1.0, 0.55, 0.2)

var _firing := false
var _heat := 0.0
var _wait := 0.0
var _jet: Node3D
var _emitters: Array[GPUParticles3D] = []
var _light := OmniLight3D.new()


func _init() -> void:
	cooldown_on_cast = false  # the wait is only the overheating lockout


func _ready() -> void:
	_jet = Node3D.new()
	_jet.top_level = true
	add_child(_jet)
	for emitter in FireVfx.jet(REACH, JET_SPEED):
		emitter.emitting = false
		_jet.add_child(emitter)
		_emitters.append(emitter)
	_light.light_color = LIGHT_COLOR
	_light.omni_range = 11.0
	_light.omni_attenuation = 0.9
	_light.light_energy = 0.0
	_light.position.z = -3.0
	_jet.add_child(_light)


func gauge() -> float:
	return _heat


func _cast() -> bool:
	if not caster.begin_cast(Player.ANIM_CHANNEL, INF, 1.8, Player.CHANNEL_HOLD):
		return false
	_firing = true
	_wait = 0.0
	return true


func release() -> void:
	if _firing:
		_stop(false)


func _update(delta: float) -> void:
	for emitter in _emitters:
		emitter.emitting = _firing
	if not _firing:
		_heat = maxf(_heat - COOL_PER_SECOND * delta, 0.0)
		return
	_heat += HEAT_PER_SECOND * delta
	if _heat >= 1.0:
		_stop(true)
		return
	if not caster.spend_mana(DRAIN * delta):
		_stop(false)
		return
	_aim_jet()
	_wait -= delta
	if _wait <= 0.0:
		_wait += TICK
		_burn()


func _aim_jet() -> void:
	var origin := caster.cast_origin()
	var direction := (caster.aim_point() - origin).normalized()
	_jet.global_position = origin
	_jet.look_at(origin + direction)
	_light.light_energy = 2.8 * randf_range(0.8, 1.0)


func _burn() -> void:
	var origin := caster.cast_origin()
	var direction := (caster.aim_point() - origin).normalized()
	for hit in Combat.in_beam(caster, origin, direction, REACH, BASE_RADIUS, HALF_ANGLE, [caster.get_rid()]):
		var health: Health = hit["health"]
		var share := lerpf(1.0, FAR_SHARE, float(hit["distance"]) / REACH)
		health.take_damage(DAMAGE * share, element)
		health.ignite(BURN_DPS, BURN_TIME, element)


## Lets go of the trigger; [param overheated] means the wand gave out and is locked for a while.
func _stop(overheated: bool) -> void:
	_firing = false
	_light.light_energy = 0.0
	for emitter in _emitters:
		emitter.emitting = false
	caster.end_cast()
	if overheated:
		_heat = 0.0
		cooldown_left = OVERHEAT_LOCK

