class_name Fissure
extends Node3D
## A wave of stone spikes breaking the ground in a straight line away from the hero. They rise
## one after another (so a sidestep gets you clear), each with two smaller ones flanking it.
## Whoever a spike catches is hurt once, stunned and thrown up; afterwards the spikes stay as
## solid pillars for a few seconds, then sink back. Set [member origin] and [member direction]
## (horizontal) before adding it to the tree.

const COUNT := 10
const STEP := 1.55  # meters between spikes
const FIRST := 1.6  # distance of the first spike from the origin
const GAP := 0.07  # seconds between spikes
const HIT_RADIUS := 1.7
const DAMAGE := 45.0
const STUN_TIME := 1.2
const LAUNCH := 7.0  # m/s upwards
const STAND_TIME := 4.0
const CLEARANCE := 1.0  # spikes keep this far from anyone standing in the line
const PROBE := 2.5  # how far above the last ground to start looking for the next

var element: Element
var caster: Player
var origin := Vector3.ZERO
var direction := Vector3.FORWARD

var _ground := 0.0
var _hit: Array[Health] = []
var _spikes: Array[StoneSpike] = []


func _ready() -> void:
	_ground = origin.y
	for i in COUNT:
		get_tree().create_timer(i * GAP).timeout.connect(_erupt.bind(i))
	var total := COUNT * GAP + StoneSpike.RISE_TIME + STAND_TIME
	get_tree().create_timer(total).timeout.connect(_sink_all)


func _erupt(i: int) -> void:
	var along := FIRST + i * STEP
	var side := Vector3(-direction.z, 0.0, direction.x)
	var center := origin + direction * along
	var rng := RandomNumberGenerator.new()
	rng.seed = i * 31 + 7
	_place(center + side * rng.randf_range(-0.2, 0.2), 1.0 + rng.randf() * 0.35, 1.0 + rng.randf() * 0.3, i, rng)
	for sign: float in [-1.0, 1.0]:
		var flank: Vector3 = center + side * sign * rng.randf_range(0.95, 1.2) - direction * rng.randf_range(0.0, 0.5)
		_place(flank, 0.5 + rng.randf() * 0.25, 0.5 + rng.randf() * 0.35, i, rng)
	_strike(center)


func _place(at: Vector3, girth: float, tall: float, index: int, rng: RandomNumberGenerator) -> void:
	if _occupied(at, CLEARANCE + girth * 0.4):
		return
	var ground := Combat.raycast(self, Vector3(at.x, _ground + PROBE, at.z), Vector3(at.x, _ground - 8.0, at.z), [caster.get_rid()])
	if ground.is_empty():
		return
	var spike := StoneSpike.new()
	spike.variant = index + rng.randi_range(0, 2)
	spike.girth = girth
	spike.tall = tall
	spike.yaw = rng.randf() * TAU
	spike.position = ground["position"]
	add_child(spike)
	spike.erupt()
	_spikes.append(spike)
	if girth > 0.95:
		_ground = ground["position"].y
	EarthVfx.dust(self, spike.global_position, 0.7 * girth)


## Whether a living target stands within [param radius] of [param at] on the flat.
func _occupied(at: Vector3, radius: float) -> bool:
	for health: Health in get_tree().get_nodes_in_group("damageable"):
		var body := health.get_parent() as Node3D
		var flat := Vector2(body.global_position.x - at.x, body.global_position.z - at.z)
		if flat.length() < radius and absf(body.global_position.y - at.y) < 3.0:
			return true
	return false


func _strike(center: Vector3) -> void:
	for health: Health in get_tree().get_nodes_in_group("damageable"):
		var body := health.get_parent() as Node3D
		var flat := Vector2(body.global_position.x - center.x, body.global_position.z - center.z)
		if not health.is_alive() or _hit.has(health) or flat.length() > HIT_RADIUS or absf(body.global_position.y - _ground) > 3.0:
			continue
		_hit.append(health)
		EarthVfx.dust(self, body.global_position, 0.9)
		health.take_damage(DAMAGE, element)
		health.stun(STUN_TIME, element)
		health.push(Vector3.UP * LAUNCH)


func _sink_all() -> void:
	for spike in _spikes:
		if is_instance_valid(spike):
			spike.sink()
	get_tree().create_timer(StoneSpike.SINK_TIME + 0.2).timeout.connect(queue_free)
