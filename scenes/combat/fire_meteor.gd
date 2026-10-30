class_name FireMeteor
extends Node3D
## A meteor of fire called down on a spot: it streaks in from high up at a slant and, where it
## lands, burns everything in a wide circle, hardest in the middle, sets it alight and leaves the
## ground burning. The circle on the ground is marked from the moment it is called.

const SPEED := 45.0
const PATH := 72.0  # how far up the sky it starts: about a second and a half of falling
const SIZE := 2.4  # the flame crown, relative to the fireball's
const RADIUS := 6.5
const DAMAGE := 95.0
const EDGE := 0.4  # share of the damage left at the rim
const BURN_DPS := 6.0
const BURN_TIME := 3.0
const SPIN := 1.5
const SHAKE_REACH := 40.0
const SHOCKWAVE := preload("res://assets/shaders/shockwave.gdshader")
const FIRE := Color(1.0, 0.5, 0.2)

var element: Element
var caster: Player
## Where it lands, and the way it flies (set before it enters the tree).
var target := Vector3.ZERO
var direction := Vector3.DOWN
var reticle: LightReticle

var _body: Node3D
var _light := OmniLight3D.new()
var _age := 0.0
var _traveled := 0.0


func _ready() -> void:
	_body = FireVfx.fireball_body()
	_body.scale = Vector3.ONE * SIZE
	add_child(_body)
	for emitter in FireVfx.fireball_trail():
		add_child(emitter)
		emitter.position.z = 0.8
		emitter.emitting = true
	_light.light_color = FIRE
	_light.omni_range = 34.0
	_light.omni_attenuation = 1.0
	add_child(_light)
	global_position = target - direction * PATH
	look_at(global_position + direction)


func _process(delta: float) -> void:
	_age += delta
	_body.rotate_z(SPIN * delta)
	_light.light_energy = 6.0 + sin(_age * 27.0) * 1.5


func _physics_process(delta: float) -> void:
	var step := SPEED * delta
	global_position += direction * step
	_traveled += step
	if _traveled >= PATH:
		_impact()


func _impact() -> void:
	var parent := get_parent()
	var struck := Combat.blast(self, target + Vector3.UP * 0.5, RADIUS, DAMAGE, element, [caster.get_rid()], EDGE)
	for health in struck:
		health.ignite(BURN_DPS, BURN_TIME, element)
	var ground := FireGround.new()
	ground.element = element
	ground.caster = caster
	ground.position = target
	parent.add_child(ground)
	Vfx.flash(parent, target + Vector3.UP * 1.0, FIRE, 12.0, 32.0, 0.6)
	Vfx.sparks(parent, target + Vector3.UP * 0.4, FIRE, 40)
	_shell(parent)
	var away := caster.global_position.distance_to(target)
	if away < SHAKE_REACH:
		caster.shake(lerpf(0.5, 0.1, away / SHAKE_REACH))
	if reticle != null:
		reticle.fade_out(0.4)
	queue_free()


## A shell of fire that swells out across the circle and thins away.
func _shell(parent: Node) -> void:
	var material := ShaderMaterial.new()
	material.shader = SHOCKWAVE
	material.set_shader_parameter("color", Vector3(FIRE.r, FIRE.g, FIRE.b))
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 16
	sphere.rings = 8
	sphere.material = material
	var wave := MeshInstance3D.new()
	wave.mesh = sphere
	wave.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wave.scale = Vector3.ONE * 1.0
	parent.add_child(wave)
	wave.global_position = target + Vector3.UP * 0.5
	var tween := wave.create_tween().set_parallel()
	tween.tween_property(wave, "scale", Vector3.ONE * RADIUS * 2.2, 0.45).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(value: float) -> void: material.set_shader_parameter("fade", value), 1.0, 0.0, 0.45)
	tween.chain().tween_callback(wave.queue_free)
