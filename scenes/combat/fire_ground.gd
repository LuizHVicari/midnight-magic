class_name FireGround
extends Node3D
## Patch of burning ground left where a fireball lands. Plasma flames stand up from the ground
## for a few seconds and the fire hurts and ignites whatever stays in it, then it shrinks away.

const RADIUS := 3.2
const DURATION := 5.0
const DPS := 8.0
const TICK := 0.5
const BURN_DPS := 4.0
const BURN_TIME := 2.0
const FLAMES := 60
const FLAME_HEIGHT := 1.7
const GROW_TIME := 0.3
const DIE_TIME := 0.9

var element: Element
var caster: Player

var _visual := Node3D.new()
var _wait := 0.0
var _age := 0.0


func _ready() -> void:
	_visual.scale = Vector3.ZERO
	add_child(_visual)
	_visual.add_child(FireVfx.flame_field(_flame_points(), FLAME_HEIGHT))

	var embers := FireVfx.flames(RADIUS * 0.6, 28, 1.3, 0.1)
	embers.position.y = 0.3
	_visual.add_child(embers)
	embers.emitting = true

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.5, 0.2)
	light.light_energy = 2.5
	light.omni_range = RADIUS * 2.5
	light.position.y = 1.0
	_visual.add_child(light)

	var tween := create_tween()
	tween.tween_property(_visual, "scale", Vector3.ONE, GROW_TIME).set_ease(Tween.EASE_OUT)
	tween.tween_interval(DURATION - GROW_TIME - DIE_TIME)
	tween.tween_property(_visual, "scale", Vector3(0.9, 0.0, 0.9), DIE_TIME).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	_age += delta
	_wait -= delta
	if _wait > 0.0 or _age > DURATION - DIE_TIME:
		return
	_wait = TICK
	var struck := Combat.blast(self, global_position + Vector3.UP, RADIUS, DPS * TICK, element, [caster.get_rid()], 1.0)
	for health in struck:
		health.ignite(BURN_DPS, BURN_TIME, element)


## Scattered over the disc (denser in the middle), each standing on the actual ground.
func _flame_points() -> PackedVector3Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(roundi(global_position.x), roundi(global_position.z)))
	var points := PackedVector3Array()
	for i in FLAMES:
		var angle := rng.randf() * TAU
		var dist := RADIUS * 0.9 * sqrt(rng.randf()) * (0.6 + 0.4 * rng.randf())
		var at := global_position + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		points.append(Vector3(at.x - global_position.x, _ground_y(at) - global_position.y, at.z - global_position.z))
	return points


func _ground_y(at: Vector3) -> float:
	var hit := Combat.raycast(self, at + Vector3.UP * 2.5, at + Vector3.DOWN * 4.0, [caster.get_rid()])
	return at.y if hit.is_empty() else hit["position"].y
