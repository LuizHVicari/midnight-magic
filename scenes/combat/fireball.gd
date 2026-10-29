class_name Fireball
extends Node3D
## Fire's attack: a bolt of plasma shot from the wand. It flies straight and bursts on the first
## thing it touches, where it scorches whatever is there and leaves the ground burning (see
## [FireGround]). Past [constant MAX_RANGE] it burns out in the air. It faces its flight direction, so the flame tongues stream out behind
## along +Z.

const SPEED := 24.0
const IMPACT_RADIUS := 2.2
const IMPACT_DAMAGE := 15.0  # the hit itself; the burning ground does the rest
const BURN_DPS := 4.0
const BURN_TIME := 3.0
const MAX_RANGE := 26.0  # short on purpose: light reaches much further
const SIZE := 0.5  # the whole fireball, relative to the model
const SPIN := 2.0  # radians per second of the flame crown around the flight axis

var element: Element
var caster: Player
var direction := Vector3.FORWARD

var _age := 0.0
var _travelled := 0.0
var _body: Node3D
var _light := OmniLight3D.new()


func _ready() -> void:
	_body = FireVfx.fireball_body()
	_body.scale = Vector3.ONE * SIZE
	add_child(_body)
	for emitter in FireVfx.fireball_trail():
		add_child(emitter)
		emitter.position.z = 0.3
		emitter.emitting = true

	# Warm and flickering: it lights a shorter radius than light's, and the color drifts a little
	# towards red now and then, like the flames do.
	_light.light_color = Color(1.0, 0.5, 0.2)
	_light.omni_range = 13.0
	_light.omni_attenuation = 1.1
	add_child(_light)
	look_at(global_position + direction)


func _process(delta: float) -> void:
	_body.rotate_z(SPIN * delta)
	var wobble := sin(_age * 31.0) * 0.5 + sin(_age * 17.0 + 1.3) * 0.5
	_light.light_energy = 4.2 + wobble * 1.3
	_light.light_color = Color(1.0, 0.5, 0.2).lerp(Color(1.0, 0.32, 0.3), maxf(wobble, 0.0) * 0.6)


func _physics_process(delta: float) -> void:
	_age += delta
	var from := global_position
	var to := from + direction * SPEED * delta
	var hit := Combat.raycast(self, from, to, [caster.get_rid()])
	_travelled += SPEED * delta
	if hit.is_empty() and _travelled < MAX_RANGE:
		global_position = to
		return
	if hit.is_empty():
		_fizzle()
		return
	_explode(hit["position"])


## Runs out of reach: a last spray of embers and gone, no fire on the ground.
func _fizzle() -> void:
	Vfx.sparks(get_parent(), global_position, element.color, 14)
	queue_free()


func _explode(at: Vector3) -> void:
	var struck := Combat.blast(self, at, IMPACT_RADIUS, IMPACT_DAMAGE, element, [caster.get_rid()])
	for health in struck:
		health.ignite(BURN_DPS, BURN_TIME, element)
	Vfx.flash(get_parent(), at + Vector3.UP * 0.6, Color(1.0, 0.5, 0.2), 7.0, 15.0, 0.35)
	var ground := FireGround.new()
	ground.element = element
	ground.caster = caster
	ground.position = at
	get_parent().add_child(ground)
	queue_free()
