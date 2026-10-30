class_name EmberAura
extends Node3D
## A ring of embers that follows the hero for a while and burns everything that comes close,
## so melee foes pay for every step in. Lights the hero's surroundings.

const RADIUS := 3.5
const DURATION := 10.0
const DAMAGE := 7.0
const TICK := 0.5
const BURN_DPS := 4.0
const BURN_TIME := 2.0
const ORBIT := 3.0  # radians per second the embers circle
const CHIPS := 26
const FLAMES := 28
const FADE := 0.8

var element: Element
var caster: Player

var _age := 0.0
var _wait := 0.0
var _orbit := Node3D.new()
var _counter := Node3D.new()  # a second ring of embers going the other way
var _light := OmniLight3D.new()
var _ring := LightReticle.new()


func _ready() -> void:
	_ring.set_color(Color(1.0, 0.5, 0.15))
	_ring.set_radius(RADIUS)
	add_child(_ring)
	add_child(_orbit)
	add_child(_counter)
	_scatter()
	add_child(_edge_flames())
	var embers := FireVfx.flames(RADIUS * 0.6, 60, 1.4, 0.11)
	embers.position.y = 0.2
	embers.emitting = true
	add_child(embers)
	# Twinkling sparks rising all over the ring, in gold and orange.
	add_child(Vfx.sparkles(RADIUS * 0.95, 0.2, 90, 1.7, 0.26, FireVfx.MID, 1.6, RADIUS * 0.2))
	add_child(Vfx.sparkles(RADIUS * 0.5, 0.2, 36, 1.4, 0.2, FireVfx.HOT, 2.2))
	_light.light_color = Color(1.0, 0.5, 0.2)
	_light.omni_range = RADIUS * 3.0
	_light.omni_attenuation = 0.9
	_light.position.y = 1.0
	add_child(_light)
	scale = Vector3.ZERO


## Starts the time over, as if it had just been called.
func refresh() -> void:
	_age = 0.0


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= DURATION:
		queue_free()
		return
	scale = Vector3.ONE * clampf(minf(_age / 0.3, (DURATION - _age) / FADE), 0.0, 1.0)
	_orbit.rotate_y(ORBIT * delta)
	_counter.rotate_y(-ORBIT * 0.7 * delta)
	_light.light_energy = 2.6 * randf_range(0.85, 1.0)
	_wait -= delta
	if _wait > 0.0:
		return
	_wait += TICK
	_ring.pulse()
	_burn()


func _burn() -> void:
	for health: Health in get_tree().get_nodes_in_group("damageable"):
		var body := health.get_parent() as Node3D
		var offset := body.global_position - caster.global_position
		if health.is_alive() and Vector2(offset.x, offset.z).length() <= RADIUS and absf(offset.y) < 3.0:
			health.take_damage(DAMAGE, element)
			health.ignite(BURN_DPS, BURN_TIME, element)


## Chunky embers circling the hero at different heights, two rings turning opposite ways.
func _scatter() -> void:
	var colors: Array[Color] = [FireVfx.HOT * 1.4, FireVfx.MID * 1.4, FireVfx.COOL * 1.4, FireVfx.PINK * 1.4]
	var near := Vfx.orbiters(CHIPS, Vector2(RADIUS * 0.55, RADIUS * 0.95), Vector2(0.2, 2.6), colors, Vector2(0.07, 0.15), false, 13)
	var far := Vfx.orbiters(CHIPS / 2, Vector2(RADIUS * 0.3, RADIUS * 0.6), Vector2(0.3, 2.0), colors, Vector2(0.05, 0.1), false, 29)
	for piece in near.get_children():
		piece.reparent(_orbit, false)
	for piece in far.get_children():
		piece.reparent(_counter, false)
	near.free()
	far.free()


## A ring of small flames standing round the edge of the aura.
func _edge_flames() -> MultiMeshInstance3D:
	var points := PackedVector3Array()
	for i in FLAMES:
		var turn := float(i) / float(FLAMES) * TAU
		points.append(Vector3(cos(turn), 0.0, sin(turn)) * RADIUS * 0.97)
	return FireVfx.flame_field(points, 0.9, 17)
