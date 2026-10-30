class_name LightSentinel
extends Node3D
## A small sun that floats beside the hero for a while. It lights up the area around it and
## looses a lance at any foe that is fighting, in sight of it, so it keeps the hero company in a
## brawl. Light that bright is easy to see, though: it makes the hero easier for foes to notice.

const LIFETIME := 15.0
const FIRE_EVERY := 0.7
const RANGE := 32.0
const FOLLOW := 4.0
## Where it hovers, in the camera's frame: x to the left (negative), up, and behind.
const HOVER := Vector3(-1.3, 2.7, 0.9)
const GLOW_COLOR := Color(1.0, 0.9, 0.6)
const FADE := 1.0  # seconds of shrinking at the end

var element: Element
var caster: Player

var _age := 0.0
var _wait := 0.0
var _orb := MeshInstance3D.new()
var _orb_material := StandardMaterial3D.new()
var _light := OmniLight3D.new()
var _bob := randf() * TAU
var _star := MeshInstance3D.new()  # a slowly turning four-point star behind the orb
var _ring := Node3D.new()  # tiny motes circling it


func _ready() -> void:
	_orb_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_orb_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_orb_material.albedo_color = Color(2.0, 1.7, 0.9)
	var sphere := SphereMesh.new()
	sphere.radius = 0.22
	sphere.height = 0.44
	sphere.radial_segments = 12
	sphere.rings = 6
	sphere.material = _orb_material
	_orb.mesh = sphere
	_orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_orb)

	var halo := Vfx.soft_quad(1.4)
	(halo.material as StandardMaterial3D).albedo_color = Color(GLOW_COLOR, 1.0)
	var halo_node := MeshInstance3D.new()
	halo_node.mesh = halo
	(halo.material as StandardMaterial3D).billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	halo_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(halo_node)

	# A four-point star that pulses behind the orb, and glints circling and trailing it.
	var star := Vfx.star_quad(1.9)
	(star.material as StandardMaterial3D).albedo_color = Color(1.0, 0.9, 0.55)
	(star.material as StandardMaterial3D).billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_star.mesh = star
	_star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_star)
	var motes: Array[Color] = [Color(1.0, 0.95, 0.7) * 1.6, Color(1.0, 0.8, 0.35) * 1.6]
	_ring = Vfx.orbiters(9, Vector2(0.45, 0.8), Vector2(-0.35, 0.35), motes, Vector2(0.03, 0.06), false, 5)
	add_child(_ring)
	var glints := Vfx.sparkles(0.35, 0.3, 36, 1.2, 0.2, Color(1.0, 0.85, 0.4), 0.6)
	add_child(glints)
	var wake := Vfx.particles(_wake(), Vfx.soft_quad(0.3), 40, 0.9)
	wake.local_coords = false
	wake.emitting = true
	add_child(wake)

	_light.light_color = GLOW_COLOR
	_light.omni_range = 15.0
	_light.omni_attenuation = 0.9
	_light.light_energy = 1.1
	add_child(_light)
	global_position = _home()
	caster.glow_sources += 1
	scale = Vector3.ZERO


func _exit_tree() -> void:
	if caster != null:
		caster.glow_sources = maxi(caster.glow_sources - 1, 0)


## Starts the time over, as if it had just been called.
func refresh() -> void:
	_age = 0.0


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	var size := minf(_age / 0.3, 1.0) * clampf((LIFETIME - _age) / FADE, 0.0, 1.0)
	scale = Vector3.ONE * size
	global_position = global_position.lerp(_home(), 1.0 - exp(-FOLLOW * delta))
	_light.light_energy = 1.1 * randf_range(0.9, 1.0)
	_ring.rotate_y(2.2 * delta)
	_ring.rotate_x(0.9 * delta)
	_star.scale = Vector3.ONE * (1.0 + sin(_age * 3.1 + _bob) * 0.18)
	_wait -= delta
	if _wait <= 0.0:
		_fire()


## A thin drift of golden dust left behind as the orb moves.
func _wake() -> ParticleProcessMaterial:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.15
	process.direction = Vector3.UP
	process.spread = 180.0
	process.initial_velocity_min = 0.1
	process.initial_velocity_max = 0.5
	process.gravity = Vector3(0.0, -0.3, 0.0)
	process.scale_min = 0.4
	process.scale_max = 1.0
	process.scale_curve = Vfx.puff_curve()
	process.color_ramp = Vfx.ramp([Color(1.0, 0.95, 0.7) * 1.5, Color(1.0, 0.75, 0.3), Color(0, 0, 0, 1)])
	return process


## Above the hero's left shoulder as the camera sees it, bobbing a little.
func _home() -> Vector3:
	var yaw := caster.camera_pivot.rotation.y
	var basis := Basis(Vector3.UP, yaw)
	var bob := sin(Time.get_ticks_msec() / 1000.0 * 2.4 + _bob) * 0.12
	return caster.global_position + basis * Vector3(HOVER.x, HOVER.y + bob, HOVER.z)


func _fire() -> void:
	var foe := _target()
	if foe == null:
		_wait = 0.15
		return
	_wait = FIRE_EVERY
	var lance := LightLance.new()
	lance.element = element
	lance.caster = caster
	lance.position = global_position
	get_parent().add_child(lance)
	lance.launch(Health.of(foe).focus_point())
	Vfx.flash(get_parent(), global_position, GLOW_COLOR, 1.5, 6.0, 0.12)


## The nearest foe that is fighting and that the sentinel can see.
func _target() -> Foe:
	var best: Foe = null
	var best_distance := RANGE
	for foe: Foe in get_tree().get_nodes_in_group("foes"):
		var distance := global_position.distance_to(foe.global_position)
		if foe.dead or not foe.is_fighting() or distance >= best_distance:
			continue
		if not _sees(foe):
			continue
		best = foe
		best_distance = distance
	return best


func _sees(foe: Foe) -> bool:
	var health := Health.of(foe)
	var hit := Combat.raycast(self, global_position, health.focus_point(), [caster.get_rid()])
	return hit.is_empty() or Health.of(hit["collider"]) == health
