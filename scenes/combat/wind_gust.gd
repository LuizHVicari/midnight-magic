class_name WindGust
extends Node3D
## One gust of wind: an instant cone from the wand that hurts and shoves everything in it. The
## nearer, the harder it hits; the far edge only stings. The streaks play out afterwards, and
## the node frees itself. Faces its aim direction (-Z), set before it enters the tree.

const REACH := 14.0
const HALF_ANGLE := 26.0
const DAMAGE := 20.0
const FAR_SHARE := 0.55  # share of the damage left at the far end
const PUSH := 11.0  # m/s at point blank, fading with distance
const PUSH_LIFT := 0.25  # how much of the shove goes up
const DURATION := 0.6  # the streaks' trip from the wand to the far end
const STREAKS := 7
const SPIN := 5.0  # radians per second the whole vortex turns

var element: Element
var caster: Player
var direction := Vector3.FORWARD

var _vortex: MeshInstance3D
var _age := 0.0


func _ready() -> void:
	look_at(global_position + direction)
	_vortex = WindVfx.vortex(REACH, HALF_ANGLE, STREAKS)
	add_child(_vortex)
	var swirl := WindVfx.swirl(REACH, HALF_ANGLE, 45)
	add_child(swirl)
	swirl.emitting = true
	_strike()


func _process(delta: float) -> void:
	_age += delta
	_vortex.rotate_z(SPIN * delta)
	var material := _vortex.mesh.surface_get_material(0) as ShaderMaterial
	material.set_shader_parameter("progress", clampf(_age / DURATION, 0.0, 1.0))
	if _age > DURATION + 0.9:
		queue_free()


func _strike() -> void:
	for hit in Combat.in_cone(self, global_position, direction, REACH, HALF_ANGLE, [caster.get_rid()]):
		var health: Health = hit["health"]
		var near: float = 1.0 - float(hit["distance"]) / REACH
		health.take_damage(DAMAGE * lerpf(FAR_SHARE, 1.0, near), element)
		var away: Vector3 = (hit["offset"] as Vector3) * Vector3(1.0, 0.0, 1.0)
		health.push((away.normalized() + Vector3.UP * PUSH_LIFT) * PUSH * lerpf(0.4, 1.0, near))
