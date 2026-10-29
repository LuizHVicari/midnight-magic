class_name StoneSpike
extends StaticBody3D
## One spike of stone that bursts out of the ground, stands for a while as solid cover and
## sinks back. It sits on [constant Combat.STONE]: bodies that collide with that layer (the hero)
## bump into it, but spells and their line-of-sight checks pass through, so cover never makes
## an enemy untouchable. Set [member variant], [member girth] and [member tall] before adding it to the
## tree; call [method erupt] to start it.

const RISE_TIME := 0.16
const SINK_TIME := 0.55
const HEIGHT := 2.2

var variant := 0
var girth := 1.0
var tall := 1.0
var yaw := 0.0

var _mesh := MeshInstance3D.new()
var _collider := CollisionShape3D.new()


func _ready() -> void:
	collision_layer = Combat.STONE
	collision_mask = 0
	_mesh.mesh = EarthVfx.spike_mesh(variant)
	_mesh.material_override = EarthVfx.spike_material()
	_mesh.scale = Vector3(girth, tall, girth)
	_mesh.rotation.y = yaw
	_mesh.position.y = -HEIGHT * tall
	add_child(_mesh)

	var shape := CylinderShape3D.new()
	shape.radius = 0.42 * girth
	shape.height = HEIGHT * tall * 0.9
	_collider.shape = shape
	_collider.position.y = shape.height * 0.5
	_collider.disabled = true
	add_child(_collider)


## Bursts upward. It only becomes solid once it is mostly out, so nothing gets stuck in it.
func erupt() -> void:
	var tween := create_tween().set_parallel()
	tween.tween_property(_mesh, "position:y", 0.0, RISE_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(func() -> void: _collider.disabled = false).set_delay(RISE_TIME * 0.6)


## Shudders, drops back into the ground and removes itself.
func sink() -> void:
	_collider.set_deferred("disabled", true)
	var tween := create_tween()
	tween.tween_property(_mesh, "position:x", 0.06, 0.05)
	tween.tween_property(_mesh, "position:x", -0.06, 0.05)
	tween.tween_property(_mesh, "position:y", -HEIGHT * tall, SINK_TIME).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)
