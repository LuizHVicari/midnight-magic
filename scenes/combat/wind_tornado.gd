class_name WindTornado
extends Node3D
## A tornado standing on the ground for a few seconds. It drags every walking creature near it
## in towards its middle while swirling them round, so scattered foes end up in one heap, and the
## ones that reach the middle are lifted off the ground and spun. It only scratches them. It
## does not touch the hero who called it.

const SHADER := preload("res://assets/shaders/wind_column.gdshader")
const PULL_RADIUS := 7.5
const CORE_RADIUS := 1.4
const HEIGHT := 9.0
const LIFETIME := 7.0
const PULL_SPEED := 8.0  # m/s inwards, strongest close in
const SWIRL := 4.0  # sideways speed round the middle
const CORE_LIFT := 3.5
const FLOAT_HEIGHT := 3.0  # how high above the ground the middle holds them up
const DAMAGE := 1.0
const TICK := 0.5
const FADE_TIME := 1.0
const SPIN := 4.5  # radians per second the debris circles
const MINT := Color(0.7, 1.0, 0.88)
const DEBRIS := 60

var element: Element
var caster: Player

var _age := 0.0
var _tick := 0.0
var _material := ShaderMaterial.new()
var _debris := Node3D.new()


func _ready() -> void:
	var funnel := CylinderMesh.new()
	funnel.top_radius = 3.4
	funnel.bottom_radius = 0.35
	funnel.height = HEIGHT
	funnel.radial_segments = 24
	funnel.rings = 12
	funnel.cap_top = false
	funnel.cap_bottom = false
	_material.shader = SHADER
	_material.set_shader_parameter("color", Vector3(MINT.r, MINT.g, MINT.b))
	_material.set_shader_parameter("height", HEIGHT)
	_material.set_shader_parameter("flow", 2.4)
	_material.set_shader_parameter("twist", 3.5)
	_material.set_shader_parameter("bands", 9.0)
	_material.set_shader_parameter("sway", 0.5)
	_material.set_shader_parameter("strength", 2.6)
	funnel.material = _material
	var body := MeshInstance3D.new()
	body.mesh = funnel
	body.position.y = HEIGHT * 0.5
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(body)
	add_child(_debris)
	_scatter_debris()
	add_child(Vfx.sparkles(3.0, 0.5, 80, 1.6, 0.28, MINT, 3.0, 0.8))
	Vfx.sparks(get_parent(), global_position + Vector3.UP * 0.3, MINT, 16)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	_material.set_shader_parameter("fade", clampf((LIFETIME - _age) / FADE_TIME, 0.0, 1.0))
	_debris.rotate_y(SPIN * delta)
	_tick += delta
	var hurt := _tick >= TICK
	if hurt:
		_tick -= TICK
	for health: Health in get_tree().get_nodes_in_group("damageable"):
		var animal := health.get_parent() as Animal
		if animal != null and not animal.dead:
			_grip(animal, health, hurt)


## Drags one creature towards the middle and round it, harder the closer it is.
func _grip(animal: Animal, health: Health, hurt: bool) -> void:
	var offset := global_position - animal.global_position
	if absf(offset.y) > HEIGHT:
		return
	var flat := Vector3(offset.x, 0.0, offset.z)
	var dist := flat.length()
	if dist > PULL_RADIUS:
		return
	var inward := flat / maxf(dist, 0.001)
	var swirl := Vector3(-inward.z, 0.0, inward.x)
	var near := 1.0 - dist / PULL_RADIUS
	var settle := minf(dist / 1.5, 1.0)  # slows to a stop at the middle instead of jittering
	animal.pull(inward * PULL_SPEED * lerpf(0.35, 1.0, near) * settle + swirl * SWIRL * near)
	if dist < CORE_RADIUS and animal.global_position.y - global_position.y < FLOAT_HEIGHT:
		animal.lift(CORE_LIFT)
	if hurt:
		health.take_damage(DAMAGE, element)


## Specks of dirt and leaves circling the funnel, wider the higher they are.
func _scatter_debris() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var colors := [Color(0.75, 0.95, 0.85), Color(0.45, 0.7, 0.4), Color(0.6, 0.5, 0.35), Color(1, 1, 1)]
	for i in DEBRIS:
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = colors[i % colors.size()]
		var chip := BoxMesh.new()
		chip.size = Vector3(0.22, 0.05, 0.14) * rng.randf_range(0.7, 1.5)
		chip.material = material
		var piece := MeshInstance3D.new()
		piece.mesh = chip
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var up := rng.randf_range(0.5, HEIGHT)
		var turn := rng.randf() * TAU
		var radius := lerpf(0.5, 3.4, up / HEIGHT) * rng.randf_range(0.8, 1.15)
		piece.position = Vector3(cos(turn) * radius, up, sin(turn) * radius)
		piece.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
		_debris.add_child(piece)
