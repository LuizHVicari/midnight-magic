class_name LightBolt
extends Node3D
## The light cannon's shot: a thick, bright bolt that crosses the field almost at once and goes
## through the first few things in its way, weaker with each one, until it meets the world.

const SPEED := 130.0
const LENGTH := 9.0
const WIDTH := 0.9  # how far from the middle of its path it still hurts
const DAMAGE := 70.0
const PIERCE := 3  # creatures it can pass through before it ends
const FALLOFF := 0.7  # share of the damage kept after each creature
const MAX_RANGE := 160.0
const GLOW_COLOR := Color(1.0, 0.9, 0.6)

var element: Element
var caster: Player
var direction := Vector3.FORWARD

var _traveled := 0.0
var _hit: Array[RID] = []
var _damage := DAMAGE
var _body := Node3D.new()


func _ready() -> void:
	# Tip at the origin, the streak trailing along +Z: a wide soft halo under a thick hot core.
	_body.add_child(LightStreak.layer(1.1, 0.0, LENGTH, 0.0, element.color, 1.2, 0.8, 1.1, 0.5, 0.4, 0.06))
	_body.add_child(LightStreak.layer(0.7, 0.0, LENGTH * 0.9, 0.0, element.color, 1.4, 0.9, 1.0, 0.6, 0.6, 0.04))
	_body.add_child(LightStreak.layer(0.34, 0.0, LENGTH * 0.8, 0.0, element.color, 1.8, 1.0, 0.8, 0.7, 1.0, 0.02))
	add_child(_body)

	var motes := Vfx.motes(element.color, 80, 0.5, LENGTH, 0.5)
	motes.position.z = LENGTH * 0.5
	add_child(motes)
	motes.emitting = true

	var glow := OmniLight3D.new()
	glow.light_color = GLOW_COLOR
	glow.omni_range = 20.0
	glow.omni_attenuation = 0.9
	glow.light_energy = 1.4
	glow.position.z = LENGTH * 0.3
	add_child(glow)
	look_at(global_position + direction)
	Vfx.sparks(get_parent(), global_position, element.color, 22)
	Vfx.flash(get_parent(), global_position, GLOW_COLOR, 5.0, 16.0, 0.35)


func _physics_process(delta: float) -> void:
	var from := global_position
	var step := SPEED * delta
	var to := from + direction * step
	var hit := Combat.raycast(self, from, to, _excluded())
	if hit.is_empty():
		global_position = to
		_traveled += step
		_sweep()
		if _traveled > MAX_RANGE:
			queue_free()
		return
	global_position = hit["position"]
	_strike(hit["collider"], hit["position"])


func _excluded() -> Array[RID]:
	var exclude: Array[RID] = [caster.get_rid()]
	exclude.append_array(_hit)
	return exclude


## The bolt is wide: anything alive within [constant WIDTH] of where it is gets hit, not only what
## lies exactly on its line.
func _sweep() -> void:
	var shape := SphereShape3D.new()
	shape.radius = WIDTH
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, global_position)
	query.collision_mask = Combat.WORLD
	query.exclude = _excluded()
	for result in get_world_3d().direct_space_state.intersect_shape(query, 8):
		if Health.of(result["collider"]) != null and is_inside_tree():
			_strike(result["collider"], global_position)
			if is_queued_for_deletion():
				return


## Hurts what was hit and goes on through it, or ends against anything it cannot hurt.
func _strike(collider: Node, at: Vector3) -> void:
	var health := Combat.hurt(collider, _damage, element)
	Vfx.sparks(get_parent(), at, element.color, 14)
	Vfx.flash(get_parent(), at + Vector3.UP * 0.3, GLOW_COLOR, 3.5, 10.0, 0.25)
	if health == null or _hit.size() + 1 >= PIERCE:
		queue_free()
		return
	_hit.append((collider as CollisionObject3D).get_rid())
	_damage *= FALLOFF
