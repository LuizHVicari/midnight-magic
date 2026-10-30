class_name WindBomb
extends Node3D
## A small ball of compressed wind that goes off where it lands, or a few meters from the hand
## if it lands nowhere, so it always works close to the hero. Nobody is really hurt by it, but
## everything near is thrown away from the blast, the thrower included: thrown at your own feet
## it lifts you, so a steady stream of them can keep you up and carry you along.

const SHOCKWAVE := preload("res://assets/shaders/shockwave.gdshader")
const SPEED := 34.0
const MAX_TRAVEL := 3.0  # goes off on its own after this far if it hits nothing
const RADIUS := 5.0
const HERO_SHOVE := 15.0  # m/s at the center of the blast
const OTHER_SHOVE := 12.0
const LIFT := 0.35  # how much of the shove is turned upwards
const MIN_SHARE := 0.3  # share of the shove left at the very edge
const DAMAGE := 3.0  # a token, enough to count as an attack
const HERO_CENTER := Vector3(0.0, 1.0, 0.0)
const MINT := Color(0.55, 1.0, 0.82)
const BLAST_TIME := 0.28

var element: Element
var caster: Player
var direction := Vector3.FORWARD

var _traveled := 0.0


func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = Color(MINT, 1.0) * 1.3
	var ball := SphereMesh.new()
	ball.radius = 0.17
	ball.height = 0.34
	ball.radial_segments = 10
	ball.rings = 5
	ball.material = material
	var body := MeshInstance3D.new()
	body.mesh = ball
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(body)
	add_child(_trail())


func _physics_process(delta: float) -> void:
	var step := minf(SPEED * delta, MAX_TRAVEL - _traveled)
	var hit := Combat.raycast(self, global_position, global_position + direction * step, [caster.get_rid()])
	if not hit.is_empty():
		global_position = hit["position"] + (hit["normal"] as Vector3) * 0.1
		_explode()
		return
	global_position += direction * step
	_traveled += step
	if _traveled >= MAX_TRAVEL:
		_explode()


func _explode() -> void:
	var center := global_position
	_shove(caster.health, caster.global_position + HERO_CENTER, center, HERO_SHOVE)
	for health: Health in get_tree().get_nodes_in_group("damageable"):
		if health.focus_point().distance_to(center) > RADIUS:
			continue
		health.take_damage(DAMAGE, element)
		_shove(health, health.focus_point(), center, OTHER_SHOVE)
	_show(center)
	queue_free()


## Throws [param health]'s owner away from [param center], harder the nearer it is.
func _shove(health: Health, at: Vector3, center: Vector3, strength: float) -> void:
	var offset := at - center
	var reach := offset.length()
	if reach > RADIUS:
		return
	var away := (offset.normalized() + Vector3.UP * LIFT).normalized()
	health.push(away * strength * lerpf(1.0, MIN_SHARE, reach / RADIUS))


## A shell of wind that swells and thins out, and a spray of flecks.
func _show(center: Vector3) -> void:
	var parent := get_parent()
	Vfx.sparks(parent, center, MINT, 18)
	var material := ShaderMaterial.new()
	material.shader = SHOCKWAVE
	material.set_shader_parameter("color", Vector3(MINT.r, MINT.g, MINT.b))
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 16
	sphere.rings = 8
	sphere.material = material
	var wave := MeshInstance3D.new()
	wave.mesh = sphere
	wave.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wave.scale = Vector3.ONE * 0.4
	parent.add_child(wave)
	wave.global_position = center
	var tween := wave.create_tween().set_parallel()
	tween.tween_property(wave, "scale", Vector3.ONE * RADIUS * 1.7, BLAST_TIME).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(value: float) -> void: material.set_shader_parameter("fade", value), 1.0, 0.0, BLAST_TIME)
	tween.chain().tween_callback(wave.queue_free)


func _trail() -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 180.0
	process.initial_velocity_min = 0.2
	process.initial_velocity_max = 0.8
	process.gravity = Vector3.ZERO
	process.scale_min = 0.5
	process.scale_max = 1.0
	process.color_ramp = Vfx.ramp([Color(MINT * 1.8, 1.0), Color(MINT, 0.0)])
	var emitter := Vfx.particles(process, Vfx.soft_quad(0.28), 24, 0.35)
	emitter.local_coords = false
	emitter.emitting = true
	return emitter
