class_name StoneBlock
extends StaticBody3D
## A block of stone the hero raised: a pillar, a wall or a heap of rubble. It rises out of the
## ground, stands solid (on [constant Combat.STONE]: bodies bump into it and foes cannot see through
## it, but spells pass through) and can be hurt: arrows, explosions and the blows of foes that are
## stuck behind it wear it down. It crumbles when its [member life] runs out or its hit points do,
## and starts to shudder in the last moments. It lifts whatever was standing where it rises. Set [member size], [member hit_points] and [member life] before adding it to the tree.

const RISE_TIME := 0.22
const SINK_TIME := 0.5
const WARN := 2.0  # seconds of shuddering before it goes
const BLOCKS := "stone_blocks"

var size := Vector3(2.0, 3.0, 2.0)
var hit_points := 40.0
var life := 10.0
var seed_value := 1
var rise_time := RISE_TIME
var health := Health.new()
## What stands on it when it rises, which it lifts with it.
var riders: Array[Node3D] = []

var _mesh := MeshInstance3D.new()
var _material := EarthVfx.spike_material()
var _collider := CollisionShape3D.new()
var _age := 0.0
var _gone := false
var _shake := 0.0


func _init() -> void:
	collision_layer = Combat.STONE
	collision_mask = 0


func _ready() -> void:
	add_to_group(BLOCKS)
	_mesh.mesh = EarthVfx.block_mesh(size, seed_value, 0.12 if size.y > size.x else 0.06)
	_mesh.material_override = _material
	_mesh.position.y = -size.y
	add_child(_mesh)
	var box := BoxShape3D.new()
	box.size = size
	_collider.shape = box
	_collider.position.y = -size.y * 0.5
	add_child(_collider)
	health.name = "Health"
	health.maximum = hit_points
	health.targetable = false  # light lances and such do not home in on stone
	add_child(health)
	health.damaged.connect(_on_hit)
	health.died.connect(crumble)
	# The mesh and its collision shape climb together out of the ground.
	var tween := create_tween().set_parallel().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(_mesh, "position:y", 0.0, rise_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_collider, "position:y", size.y * 0.5, rise_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	EarthVfx.dust(get_parent(), global_position + Vector3.UP * size.y, maxf(size.x, size.z))


func _physics_process(delta: float) -> void:
	if _gone:
		return
	_age += delta
	if _age < rise_time + 0.15:
		_lift_riders()
	if _age >= life:
		crumble()
		return
	_shake = maxf(_shake - delta * 4.0, 0.0)
	var warning := _age > life - WARN
	var wobble := _shake * 0.12 + (0.05 if warning else 0.0)
	_mesh.position.x = sin(_age * 55.0) * wobble


## The bodies of every stone block standing now, so explosions can leave them out.
static func bodies(tree: SceneTree) -> Array[RID]:
	var found: Array[RID] = []
	for block in tree.get_nodes_in_group(BLOCKS):
		var body := block as CollisionObject3D
		if body != null:
			found.append(body.get_rid())
	return found


## Keeps whatever was standing where it rose on top of it as it climbs.
func _lift_riders() -> void:
	var top := global_position.y + _mesh.position.y + size.y + 0.02
	for rider in riders:
		if is_instance_valid(rider) and rider.global_position.y < top:
			rider.global_position.y = top
			if rider is CharacterBody3D:
				(rider as CharacterBody3D).velocity.y = 0.0


## How much damage is left in it.
func remaining() -> float:
	return health.value


## Where it would burst from.
func blast_center() -> Vector3:
	return global_position + Vector3.UP * size.y * 0.5


## The point of its footprint nearest to [param from], on the ground plane: a foe reaches it from
## there.
func nearest_point(from: Vector3) -> Vector3:
	var local := to_local(from)
	var clamped := Vector3(clampf(local.x, -size.x * 0.5, size.x * 0.5), 0.0, clampf(local.z, -size.z * 0.5, size.z * 0.5))
	return to_global(clamped)


func _on_hit(amount: float, _element: Element) -> void:
	_shake = 1.0
	var left := clampf(health.value / health.maximum, 0.0, 1.0)
	_material.albedo_color = Color(1, 1, 1).lerp(Color(0.55, 0.45, 0.42), 1.0 - left)
	Vfx.sparks(get_parent(), blast_center(), EarthVfx.TIP, 4 + int(amount / 10.0))


## Breaks apart in a cloud of dust and sinks away.
func crumble() -> void:
	if _gone:
		return
	_gone = true
	remove_from_group(BLOCKS)
	_collider.set_deferred("disabled", true)
	EarthVfx.dust(get_parent(), blast_center(), maxf(size.x, size.z))
	var tween := create_tween()
	tween.tween_property(_mesh, "position:y", -size.y, SINK_TIME).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


## Gone at once, for the caster's shattering (which does the damage itself).
func shatter() -> void:
	if _gone:
		return
	crumble()
