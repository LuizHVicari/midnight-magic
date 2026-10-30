class_name StoneCocoon
extends Node3D
## A shell of stone that closes round one foe. It cannot move or act while the shell stands, and
## takes more damage from everything but earth, as any stunned target does. The shell has hit
## points of its own that every blow the prisoner takes wears down, so hitting it is how it is
## broken. It also gives way after a few seconds, and bursts if its caster shatters it.

const SLABS := 9
const RISE_TIME := 0.25
const SINK_TIME := 0.4

var element: Element
var foe: Animal
var hit_points := 100.0
var life := 7.0

var _health: Health
var _left := 0.0
var _age := 0.0
var _gone := false
var _slabs := Node3D.new()


func _ready() -> void:
	add_to_group(StoneBlock.BLOCKS)
	_health = Health.of(foe)
	_left = hit_points
	_health.damaged.connect(_on_prisoner_hurt)
	_health.died.connect(_free_prisoner)
	_health.stun(life + 0.5, element)
	global_position = foe.global_position
	add_child(_slabs)
	_build()
	_slabs.scale = Vector3(1.0, 0.05, 1.0)
	create_tween().tween_property(_slabs, "scale", Vector3.ONE, RISE_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	EarthVfx.dust(get_parent(), global_position + Vector3.UP * 0.5, 2.0)


func _physics_process(delta: float) -> void:
	if _gone:
		return
	_age += delta
	if not is_instance_valid(foe) or foe.dead or _age >= life:
		break_open()
		return
	global_position = foe.global_position
	_health.stun(maxf(life - _age, 0.2) + 0.3, element)


func remaining() -> float:
	return _left


func blast_center() -> Vector3:
	return global_position + Vector3.UP * 1.0


func _on_prisoner_hurt(amount: float, source: Element) -> void:
	if source == element:
		return  # the caster's own earth magic does not crack its shell
	_left -= amount
	_slabs.position.x = 0.05
	if _left <= 0.0:
		break_open()


## The shell comes apart and the prisoner is free.
func break_open() -> void:
	if _gone:
		return
	_gone = true
	remove_from_group(StoneBlock.BLOCKS)
	if is_instance_valid(foe) and not foe.dead:
		_health.release_stun()
	_release_signals()
	EarthVfx.dust(get_parent(), blast_center(), 3.0)
	var tween := create_tween()
	tween.tween_property(_slabs, "scale", Vector3(1.15, 0.02, 1.15), SINK_TIME).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


## Bursts the shell, for the caster's shattering.
func shatter() -> void:
	break_open()


func _free_prisoner() -> void:
	break_open()


func _release_signals() -> void:
	if _health.damaged.is_connected(_on_prisoner_hurt):
		_health.damaged.disconnect(_on_prisoner_hurt)
	if _health.died.is_connected(_free_prisoner):
		_health.died.disconnect(_free_prisoner)


## A ring of stone slabs leaning in over the prisoner's head, with a cap of rock on top.
func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	var height := 2.5 * foe.species.model_scale
	for i in SLABS:
		var turn := TAU * i / SLABS
		var slab := MeshInstance3D.new()
		slab.mesh = EarthVfx.block_mesh(Vector3(0.75, height * rng.randf_range(0.85, 1.1), 0.32), 61 + i, 0.3)
		slab.material_override = EarthVfx.spike_material()
		slab.position = Vector3(cos(turn), 0.0, sin(turn)) * 0.85
		slab.rotation.y = -turn + PI / 2.0
		slab.rotation.x = -deg_to_rad(rng.randf_range(10.0, 22.0))  # leaning in over the head
		_slabs.add_child(slab)
	var cap := MeshInstance3D.new()
	cap.mesh = EarthVfx.block_mesh(Vector3(1.3, 0.5, 1.3), 77, 0.4)
	cap.material_override = EarthVfx.spike_material()
	cap.position.y = height * 0.95
	_slabs.add_child(cap)
