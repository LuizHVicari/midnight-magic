class_name ShadowDecoy
extends Node3D
## A copy of the hero made of shadow, standing still where it was put. Foes that are not fighting
## and are within its reach hear it and come to look, and keep coming back to it for as long as it
## stands, so a camp can be drawn away from the way you want to go. At night it lasts longer and
## draws from farther. It breaks apart when its time is up.

const MODEL := preload("res://assets/models/kaykit/Mage.glb")
const GENERAL := "res://assets/animations/Rig_Medium_General.glb"
const IDLE := "Rig_Medium_General/Idle_A"
const SILHOUETTE := preload("res://assets/shaders/shadow_silhouette.gdshader")
const GROUND := preload("res://assets/shaders/dark_ground.gdshader")
const LURE_EVERY := 1.0
const LURE_STRENGTH := 0.6
const VIOLET := Color(0.6, 0.25, 0.92)
const FORM_TIME := 0.4
const BREAK_TIME := 0.7

## Set before it enters the tree.
var reach := 28.0
var duration := 10.0
## Which way it faces: the way the hero was facing when they made it.
var facing := Vector3.FORWARD

var _age := 0.0
var _lure := 0.0
var _model: Node3D
var _material := ShaderMaterial.new()
var _ground_material := ShaderMaterial.new()
var _breaking := false


func _ready() -> void:
	_material.shader = SILHOUETTE
	_model = MODEL.instantiate()
	_model.name = "Model"
	_model.rotation.y = atan2(facing.x, facing.z)
	add_child(_model)
	for mesh_node: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		mesh_node.material_override = _material
		mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var animations := AnimationPlayer.new()
	add_child(animations)
	animations.root_node = NodePath("../Model")
	animations.add_animation_library("Rig_Medium_General", load(GENERAL))
	animations.get_animation(IDLE).loop_mode = Animation.LOOP_LINEAR
	animations.play(IDLE)
	_material.set_shader_parameter("fade", 0.0)

	_ground_material.shader = GROUND
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 3.0
	quad.material = _ground_material
	var disc := MeshInstance3D.new()
	disc.mesh = quad
	disc.rotation_degrees.x = -90.0
	disc.position.y = 0.1
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)

	add_child(_smoke())
	add_child(Vfx.sparkles(0.9, 1.6, 40, 1.8, 0.2, VIOLET, 0.7))
	ShadowVfx.vanish(get_parent(), global_position + Vector3.UP * 0.6)
	var form := create_tween().set_parallel()
	form.tween_method(_set_fade, 0.0, 1.0, FORM_TIME)
	form.tween_property(_model, "scale", Vector3.ONE, FORM_TIME).from(Vector3(0.6, 0.2, 0.6)).set_ease(Tween.EASE_OUT)


func _physics_process(delta: float) -> void:
	_age += delta
	if not _breaking and _age >= duration - BREAK_TIME:
		_break()
	if _breaking:
		return
	_lure -= delta
	if _lure > 0.0:
		return
	_lure = LURE_EVERY
	for foe: Foe in get_tree().get_nodes_in_group("foes"):
		if not foe.dead and not foe.is_fighting() and not foe.is_afraid() and foe.global_position.distance_to(global_position) <= reach:
			foe.hear_alarm(global_position, LURE_STRENGTH)


## Comes apart into smoke.
func _break() -> void:
	_breaking = true
	ShadowVfx.vanish(get_parent(), global_position + Vector3.UP * 1.0)
	var tween := create_tween().set_parallel()
	tween.tween_method(_set_fade, 1.0, 0.0, BREAK_TIME)
	tween.tween_property(_model, "scale", Vector3(1.2, 0.05, 1.2), BREAK_TIME).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)


func _set_fade(value: float) -> void:
	_material.set_shader_parameter("fade", value)
	_ground_material.set_shader_parameter("fade", value)


## A low drift of dark smoke at its feet.
func _smoke() -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	process.emission_ring_axis = Vector3.UP
	process.emission_ring_radius = 0.8
	process.emission_ring_inner_radius = 0.2
	process.emission_ring_height = 0.1
	process.direction = Vector3.UP
	process.spread = 25.0
	process.initial_velocity_min = 0.3
	process.initial_velocity_max = 1.1
	process.gravity = Vector3.ZERO
	process.scale_min = 0.8
	process.scale_max = 1.5
	process.scale_curve = Vfx.puff_curve()
	process.color_ramp = Vfx.ramp([Color(0.02, 0.0, 0.05, 0.0), Color(0.06, 0.01, 0.12, 0.6), Color(0.03, 0.0, 0.07, 0.0)])
	var emitter := Vfx.particles(process, Vfx.alpha_quad(1.4), 30, 2.4)
	emitter.local_coords = false
	emitter.emitting = true
	return emitter
