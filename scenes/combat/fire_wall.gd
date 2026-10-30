class_name FireWall
extends Node3D
## A wall of flame standing on the ground for a few seconds. It hurts and ignites everything that
## stands in it, and foes try to walk round it instead of through. It runs across the way the hero
## was aiming, centered where they aimed.

const LENGTH := 10.0
const SPACING := 1.0
const HALF_WIDTH := 1.3  # how close to the line of flames counts as being in the fire
const REACH_UP := 3.5
const HEIGHT := 2.4
const DURATION := 8.0
const DAMAGE := 8.0
const TICK := 0.4
const BURN_DPS := 5.0
const BURN_TIME := 2.5
const GROW_TIME := 0.35
const DIE_TIME := 0.8

var element: Element
var caster: Player
## Which way the wall runs along the ground, set before it enters the tree.
var along := Vector3.RIGHT

var _points := PackedVector3Array()  # world positions of the flames
var _visual := Node3D.new()
var _wait := 0.0


func _ready() -> void:
	add_to_group("fire_walls")
	var count := int(LENGTH / SPACING) + 1
	for i in count:
		var spot := global_position + along * (i - (count - 1) * 0.5) * SPACING
		var hit := Combat.raycast(self, spot + Vector3.UP * 20.0, spot + Vector3.DOWN * 20.0)
		_points.append(hit["position"] if not hit.is_empty() else spot)
	var local_points := PackedVector3Array()
	for point in _points:
		local_points.append(point - global_position)
	_visual.scale = Vector3.ZERO
	add_child(_visual)
	_visual.add_child(FireVfx.flame_field(local_points, HEIGHT, 5))
	_visual.add_child(FireVfx.flame_field(local_points, HEIGHT * 0.7, 9))
	for i in range(0, count, 3):
		var embers := FireVfx.flames(0.6, 10, 1.2, 0.1)
		embers.position = local_points[i] + Vector3.UP * 0.3
		_visual.add_child(embers)
		embers.emitting = true
	for fraction in [0.0, 0.5, 1.0]:
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.5, 0.2)
		light.light_energy = 2.4
		light.omni_range = 9.0
		light.position = local_points[int(fraction * (count - 1))] + Vector3.UP * 1.2
		_visual.add_child(light)
	var tween := create_tween()
	tween.tween_property(_visual, "scale", Vector3.ONE, GROW_TIME).set_ease(Tween.EASE_OUT)
	tween.tween_interval(DURATION - GROW_TIME - DIE_TIME)
	tween.tween_property(_visual, "scale", Vector3(1.0, 0.0, 1.0), DIE_TIME).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0:
		return
	_wait += TICK
	for health: Health in get_tree().get_nodes_in_group("damageable"):
		if health.is_alive() and covers(health.get_parent().global_position):
			health.take_damage(DAMAGE, element)
			health.ignite(BURN_DPS, BURN_TIME, element)


## Whether [param point] is inside the fire: near one of the flames and not far above or below.
func covers(point: Vector3) -> bool:
	for flame in _points:
		var flat := Vector2(point.x - flame.x, point.z - flame.z)
		if flat.length() <= HALF_WIDTH and point.y >= flame.y - 1.0 and point.y <= flame.y + REACH_UP:
			return true
	return false
