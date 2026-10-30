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
const CHIPS := 20
const FADE := 0.8

var element: Element
var caster: Player

var _age := 0.0
var _wait := 0.0
var _orbit := Node3D.new()
var _light := OmniLight3D.new()
var _ring := LightReticle.new()


func _ready() -> void:
	_ring.set_color(Color(1.0, 0.5, 0.15))
	_ring.set_radius(RADIUS)
	add_child(_ring)
	add_child(_orbit)
	_scatter()
	var embers := FireVfx.flames(RADIUS * 0.5, 34, 1.3, 0.1)
	embers.position.y = 0.2
	embers.emitting = true
	add_child(embers)
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
	_light.light_energy = 2.6 * randf_range(0.85, 1.0)
	_wait -= delta
	if _wait > 0.0:
		return
	_wait += TICK
	_burn()


func _burn() -> void:
	for health: Health in get_tree().get_nodes_in_group("damageable"):
		var body := health.get_parent() as Node3D
		var offset := body.global_position - caster.global_position
		if health.is_alive() and Vector2(offset.x, offset.z).length() <= RADIUS and absf(offset.y) < 3.0:
			health.take_damage(DAMAGE, element)
			health.ignite(BURN_DPS, BURN_TIME, element)


## Chunky embers circling the hero at different heights and in the fire colors.
func _scatter() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var colors: Array[Color] = [FireVfx.HOT, FireVfx.MID, FireVfx.COOL, FireVfx.PINK]
	for i in CHIPS:
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = colors[i % colors.size()] * 1.4
		var chip := SphereMesh.new()
		chip.radius = rng.randf_range(0.07, 0.14)
		chip.height = chip.radius * 2.0
		chip.radial_segments = 4
		chip.rings = 2
		chip.material = material
		var piece := MeshInstance3D.new()
		piece.mesh = chip
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var turn := rng.randf() * TAU
		var radius := rng.randf_range(RADIUS * 0.55, RADIUS * 0.95)
		piece.position = Vector3(cos(turn) * radius, rng.randf_range(0.2, 2.4), sin(turn) * radius)
		_orbit.add_child(piece)
