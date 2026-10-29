class_name ShadowWisp
extends Node3D
## Shadow's attack: a wisp of living darkness. It curves hard towards whatever it was aimed near,
## hits for a moderate amount and leaves a curse that stacks, ticking on its own: lone wisps
## are weak, a stream of them wears a target down. Past [constant MAX_RANGE] it dissolves.

const SPEED := 30.0
const MAX_RANGE := 60.0
const DAMAGE := 14.0
const HOMING := 6.0  # how fast the heading bends towards the target, per second
const HOMING_REACH := 60.0
const HOMING_CONE := 35.0
const CURSE_DPS := 6.0  # per stack
const CURSE_TIME := 4.0
const CURSE_STACKS := 3
const SIZE := 0.55
const SPIN := 2.5

var element: Element
var caster: Player
var direction := Vector3.FORWARD

var _target: Health
var _travelled := 0.0
var _body: Node3D
var _aura := OmniLight3D.new()


func _ready() -> void:
	_body = ShadowVfx.wisp_body()
	_body.scale = Vector3.ONE * SIZE
	add_child(_body)
	for trail in ShadowVfx.wisp_trail():
		trail.position.z = 0.25
		add_child(trail)
		trail.emitting = true

	# Negative light: the wisp darkens the ground it passes over. Neutral gray, or the subtracted
	# color would leave a tint (violet taken away turns the grass green).
	_aura.light_negative = true
	_aura.light_color = Color(0.6, 0.6, 0.6)
	_aura.light_energy = 1.6
	_aura.omni_range = 7.0
	add_child(_aura)

	_target = Combat.find_target(self, global_position, direction, HOMING_REACH, HOMING_CONE)
	look_at(global_position + direction)


func _process(delta: float) -> void:
	_body.rotate_z(SPIN * delta)


func _physics_process(delta: float) -> void:
	if _target != null and _target.is_alive():
		var wanted := (_target.focus_point() - global_position).normalized()
		direction = direction.slerp(wanted, clampf(HOMING * delta, 0.0, 1.0)).normalized()
	var from := global_position
	var to := from + direction * SPEED * delta
	var hit := Combat.raycast(self, from, to, [caster.get_rid()])
	_travelled += SPEED * delta
	if hit.is_empty() and _travelled < MAX_RANGE:
		global_position = to
		look_at(to + direction)
		return
	if hit.is_empty():
		ShadowVfx.impact(get_parent(), global_position)
		queue_free()
		return
	_land(hit)


func _land(hit: Dictionary) -> void:
	var health := Combat.hurt(hit["collider"], DAMAGE, element)
	if health != null:
		health.curse(CURSE_DPS, CURSE_TIME, CURSE_STACKS, element)
	ShadowVfx.impact(get_parent(), hit["position"])
	queue_free()
