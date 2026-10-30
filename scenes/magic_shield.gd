class_name MagicShield
extends MeshInstance3D
## Purple spell circle held in front of the hero while blocking. [raise] spins it open,
## [lower] collapses it again. Sparks drift around the circle and a stream of them flows
## into it from [wand].

const SHADER := preload("res://assets/shaders/magic_shield.gdshader")
const SPARK_COLOR := Color(0.7, 0.3, 1.0)
const STREAM_LIFETIME := 0.45
const SHATTER_TIME := 0.5

@export var diameter: float = 2.6
@export var open_time: float = 0.18
@export var close_time: float = 0.12

## Node the energy stream starts from (the wand's hand attachment).
var wand: Node3D

var _material := ShaderMaterial.new()
var _tween: Tween
var _shattering := false
var _twinkles: GPUParticles3D
var _stream: GPUParticles3D
var _wand_glow: GPUParticles3D


func _ready() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * diameter
	mesh = quad
	_material.shader = SHADER
	_material.set_shader_parameter("fade", 0.0)
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false

	_twinkles = _make_twinkles()
	_stream = _make_stream()
	_wand_glow = _make_wand_glow()
	for emitter in [_twinkles]:
		add_child(emitter)
	for emitter in [_stream, _wand_glow]:
		emitter.top_level = true
		add_child(emitter)


func _process(_delta: float) -> void:
	if not visible or not wand:
		return
	# The stream is world-space so the sparks keep their path when the hero turns; aim it at
	# the circle and size its speed so the first sparks arrive as they die.
	_stream.global_position = wand.global_position
	_wand_glow.global_position = wand.global_position
	var target := global_position
	if _stream.global_position.distance_squared_to(target) < 0.01:
		return
	_stream.look_at(target)
	var speed := _stream.global_position.distance_to(target) / STREAM_LIFETIME
	var stream_material := _stream.process_material as ParticleProcessMaterial
	stream_material.initial_velocity_min = speed * 0.85
	stream_material.initial_velocity_max = speed * 1.05


func raise() -> void:
	visible = true
	_set_emitting(true)
	_animate(1.0, open_time, Tween.EASE_OUT)


func lower() -> void:
	if _shattering:
		return
	_set_emitting(false)
	_animate(0.0, close_time, Tween.EASE_IN)
	_tween.finished.connect(func() -> void: visible = false)


## How battered the circle looks, 0 (whole) to 1 (about to break); cracks spread as it grows.
func set_damage(share: float) -> void:
	_material.set_shader_parameter("damage", clampf(share, 0.0, 1.0))


## Breaks the circle apart: its cells drop away, the cracks flare and shards fly off.
func shatter() -> void:
	if _shattering or not visible:
		return
	_shattering = true
	_set_emitting(false)
	_burst_shards()
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel()
	_tween.tween_method(_set_shatter, 0.0, 1.0, SHATTER_TIME)
	_tween.tween_property(self, "scale", Vector3.ONE * 1.25, SHATTER_TIME)
	_tween.chain().tween_callback(_finish_shatter)


func _set_shatter(value: float) -> void:
	_material.set_shader_parameter("shatter", value)


func _finish_shatter() -> void:
	_shattering = false
	visible = false
	scale = Vector3.ONE
	_material.set_shader_parameter("shatter", 0.0)
	_material.set_shader_parameter("fade", 0.0)
	set_damage(0.0)


func _burst_shards() -> void:
	var shards := _make_shards()
	shards.top_level = true
	add_child(shards)
	shards.global_position = global_position
	shards.global_rotation = global_rotation
	shards.emitting = true
	get_tree().create_timer(shards.lifetime + 0.2).timeout.connect(shards.queue_free)


func _set_emitting(on: bool) -> void:
	for emitter in [_twinkles, _stream, _wand_glow]:
		emitter.emitting = on


func _animate(target: float, time: float, easing: Tween.EaseType) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(easing)
	_tween.tween_method(_set_fade, _material.get_shader_parameter("fade"), target, time)
	_tween.tween_property(self, "scale", Vector3.ONE * lerpf(0.6, 1.0, target), time)


func _set_fade(value: float) -> void:
	_material.set_shader_parameter("fade", value)


## Four-point star flare: a bright core with thin rays, drawn additively so black is clear.
func _flare_texture() -> ImageTexture:
	var size := 64
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var p := (Vector2(x, y) + Vector2.ONE * 0.5) / size * 2.0 - Vector2.ONE
			var core := exp(-p.length_squared() * 18.0)
			var rays := exp(-minf(absf(p.x), absf(p.y)) * 38.0) * clampf(1.0 - p.length(), 0.0, 1.0)
			var v := clampf(core + rays * 0.8, 0.0, 1.0)
			image.set_pixel(x, y, Color(v, v, v, 1.0))
	return ImageTexture.create_from_image(image)


func _additive_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	return m


## Twinkling star that always faces the camera.
func _flare_mesh() -> QuadMesh:
	var m := _additive_material()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = _flare_texture()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.22
	quad.material = m
	return quad


## Comet ribbon: bright at the head, fading to nothing along its tail.
func _trail_mesh(width: float, length: float) -> RibbonTrailMesh:
	var tail := Gradient.new()
	tail.set_color(0, Color(0, 0, 0, 1))
	tail.set_color(1, Color(1, 1, 1, 1))
	var fade := GradientTexture2D.new()
	fade.gradient = tail
	fade.fill_from = Vector2(0.5, 0.0)
	fade.fill_to = Vector2(0.5, 1.0)

	var m := _additive_material()
	m.use_particle_trails = true
	m.albedo_texture = fade

	var ribbon := RibbonTrailMesh.new()
	ribbon.shape = RibbonTrailMesh.SHAPE_CROSS
	ribbon.size = width
	ribbon.sections = 4
	ribbon.section_length = length / 4.0
	ribbon.section_segments = 3
	ribbon.curve = _taper()
	ribbon.material = m
	return ribbon


func _taper() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	return curve


func _color_ramp(bright := 1.0) -> GradientTexture1D:
	var hot := Color(0.85, 0.45, 1.0) * bright
	var ramp := Gradient.new()
	ramp.set_color(0, Color(hot, 1.0))
	ramp.set_color(1, Color(SPARK_COLOR * bright, 0.0))
	var texture := GradientTexture1D.new()
	texture.gradient = ramp
	return texture


func _twinkle() -> CurveTexture:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.25, 1.0))
	curve.add_point(Vector2(0.5, 0.35))
	curve.add_point(Vector2(0.75, 0.9))
	curve.add_point(Vector2(1.0, 0.0))
	var texture := CurveTexture.new()
	texture.curve = curve
	return texture


func _particles(process: ParticleProcessMaterial, mesh: Mesh, amount: int, lifetime: float) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.emitting = false
	particles.draw_pass_1 = mesh
	particles.process_material = process
	particles.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	return particles


## Stars that blink in and out across the disc and rise off it.
func _make_twinkles() -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	process.emission_ring_axis = Vector3.BACK
	process.emission_ring_radius = diameter * 0.48
	process.emission_ring_inner_radius = 0.0
	process.emission_ring_height = 0.1
	process.direction = Vector3.UP
	process.spread = 25.0
	process.initial_velocity_min = 0.1
	process.initial_velocity_max = 0.4
	process.gravity = Vector3.ZERO
	process.scale_min = 0.4
	process.scale_max = 1.1
	process.scale_curve = _twinkle()
	process.color_ramp = _color_ramp(2.2)
	var particles := _particles(process, _flare_mesh(), 22, 1.1)
	particles.local_coords = true
	return particles


## Streaks flying from the wand into the circle, weaving around one another.
func _make_stream() -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.06
	process.direction = Vector3(0.0, 0.0, -1.0)  # look_at points the emitter's -Z at the target
	process.spread = 14.0
	process.initial_velocity_min = 5.0
	process.initial_velocity_max = 6.0
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 1.4
	process.turbulence_noise_scale = 1.6
	process.turbulence_influence_min = 0.05
	process.turbulence_influence_max = 0.15
	process.gravity = Vector3.ZERO
	process.color_ramp = _color_ramp(2.0)
	process.scale_min = 0.7
	process.scale_max = 1.2
	var particles := _particles(process, _trail_mesh(0.2, 0.7), 40, STREAM_LIFETIME)
	particles.trail_enabled = true
	particles.trail_lifetime = 0.3
	particles.local_coords = false
	return particles


## One-shot burst of glowing splinters thrown out of the broken circle.
func _make_shards() -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	process.emission_ring_axis = Vector3.BACK
	process.emission_ring_radius = diameter * 0.45
	process.emission_ring_inner_radius = 0.0
	process.emission_ring_height = 0.05
	process.direction = Vector3.BACK
	process.spread = 180.0
	process.flatness = 0.4
	process.initial_velocity_min = 1.5
	process.initial_velocity_max = 5.0
	process.gravity = Vector3(0.0, -6.0, 0.0)
	process.scale_min = 0.5
	process.scale_max = 1.4
	process.scale_curve = _twinkle()
	process.color_ramp = _color_ramp(3.0)
	var particles := _particles(process, _flare_mesh(), 46, 0.8)
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.local_coords = false
	return particles


## Pulsing halo at the tip of the wand while the spell is held.
func _make_wand_glow() -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 180.0
	process.initial_velocity_min = 0.0
	process.initial_velocity_max = 0.15
	process.gravity = Vector3.ZERO
	process.scale_min = 2.5
	process.scale_max = 3.5
	process.scale_curve = _twinkle()
	process.color_ramp = _color_ramp(3.0)
	var particles := _particles(process, _flare_mesh(), 6, 0.6)
	particles.local_coords = false
	return particles
