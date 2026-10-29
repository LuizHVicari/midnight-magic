class_name Arrow
extends Node3D
## An arrow in flight: it drops a little as it goes, is stopped by trees, rocks and stone cover,
## and hurts whatever with a [Health] it hits first. Set [member velocity], [member damage] and
## [member shooter] before adding it to the tree.

const MODEL := preload("res://assets/models/kaykit/arrow_bow.gltf")
const GRAVITY := 7.0
const LIFETIME := 4.0

var velocity := Vector3.FORWARD
var damage := 8.0
var shooter: RID
var color := Color(1.0, 0.8, 0.5)

var _age := 0.0


func _ready() -> void:
	add_child(MODEL.instantiate())
	look_at(global_position + velocity)


func _physics_process(delta: float) -> void:
	_age += delta
	velocity.y -= GRAVITY * delta
	var from := global_position
	var to := from + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(from, to, Combat.WORLD | Combat.STONE)
	query.exclude = [shooter]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() and _age < LIFETIME:
		global_position = to
		look_at(to + velocity)
		return
	if not hit.is_empty():
		_land(hit)
	queue_free()


func _land(hit: Dictionary) -> void:
	var health := Health.of(hit["collider"])
	if health == null:
		Vfx.sparks(get_parent(), hit["position"], color, 4)
		return
	health.take_damage(damage, null, global_position)
	var shove := Vector3(velocity.x, 0.0, velocity.z).normalized() * 3.0
	health.push(shove + Vector3.UP * 1.0)
	Vfx.sparks(get_parent(), hit["position"], color, 7)
