class_name DayNight
extends Node
## Day and night. A clock runs through 24 hours (a full day lasts [member day_length] real
## seconds) and everything that depends on the light follows it slowly: the sun crosses the sky
## and warms or cools its color, a moon takes over at night, the sky shifts from blue to orange
## to violet to black, stars come out, fog and ambient light change color, and the hero carries a
## soft light after dark. Colors are picked by how high the sun is, so sunrise and sunset share
## the same look. Hour 12 is noon, 0 is midnight.
## Needs a [WorldEnvironment] named "WorldEnvironment" and a [DirectionalLight3D] named
## "DirectionalLight3D" as siblings.

const SKY_SHADER := preload("res://assets/shaders/sky.gdshader")
const UPDATE_EVERY := 0.1
## Sun height (sine of its elevation) of each look, from deep night to high noon.
const STOPS := [-0.35, -0.14, -0.03, 0.05, 0.2, 0.5, 1.0]
const ZENITH := [
	Color(0.025, 0.03, 0.11), Color(0.07, 0.08, 0.25), Color(0.2, 0.18, 0.46),
	Color(0.36, 0.38, 0.72), Color(0.4, 0.58, 0.92), Color(0.36, 0.6, 0.95), Color(0.32, 0.58, 0.96),
]
const HORIZON := [
	Color(0.07, 0.09, 0.22), Color(0.17, 0.15, 0.36), Color(0.62, 0.32, 0.5),
	Color(1.0, 0.58, 0.45), Color(1.0, 0.82, 0.66), Color(0.82, 0.9, 1.0), Color(0.78, 0.9, 1.0),
]
const SUN := [
	Color(1.0, 0.5, 0.4), Color(1.0, 0.5, 0.4), Color(1.0, 0.5, 0.38),
	Color(1.0, 0.58, 0.36), Color(1.0, 0.82, 0.62), Color(1.0, 0.93, 0.8), Color(1.0, 0.96, 0.88),
]
## Ambient light color and strength, from the sky.
const AMBIENT := [
	Color(0.45, 0.52, 0.82), Color(0.5, 0.54, 0.8), Color(0.68, 0.56, 0.78),
	Color(0.95, 0.72, 0.68), Color(0.82, 0.88, 1.0), Color(0.82, 0.9, 1.0), Color(0.84, 0.92, 1.0),
]
const AMBIENT_ENERGY := [0.42, 0.44, 0.5, 0.52, 0.46, 0.42, 0.4]
const FOG_DENSITY := [0.003, 0.0028, 0.003, 0.0032, 0.0024, 0.0019, 0.0017]
const SUN_ENERGY := [0.0, 0.0, 0.0, 0.3, 0.75, 0.9, 0.9]
const MOON_ENERGY := 0.5
const MOON_COLOR := Color(0.7, 0.78, 1.0)

@export var day_length := 1200.0
@export_range(0.0, 24.0) var hour := 8.0
## Slows or speeds the clock; 0 stops time.
@export var speed := 1.0
## How many hours the time-skip key moves the clock.
@export var skip_hours := 1.0

var _environment: Environment
var _sun: DirectionalLight3D
var _moon := DirectionalLight3D.new()
var _sky := ShaderMaterial.new()
var _hero_light := OmniLight3D.new()
## How dark it is now: 0 in daylight, 1 at night. Updated as the clock runs.
var night := 0.0
var _since_update := 0.0
var _clouds := 0.6


func _ready() -> void:
	add_to_group("day_night")
	_environment = (get_parent().get_node("WorldEnvironment") as WorldEnvironment).environment
	_sun = get_parent().get_node("DirectionalLight3D")
	_sky.shader = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = _sky
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	_environment.background_mode = Environment.BG_SKY
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_environment.ambient_light_sky_contribution = 1.0
	_environment.fog_enabled = true
	_environment.fog_sky_affect = 0.0
	_environment.fog_aerial_perspective = 0.35
	_moon.name = "Moon"
	_moon.light_color = MOON_COLOR
	_moon.shadow_enabled = true
	_moon.directional_shadow_max_distance = _sun.directional_shadow_max_distance
	_moon.light_specular = 0.2
	get_parent().add_child.call_deferred(_moon)
	_apply()


func _process(delta: float) -> void:
	hour = fposmod(hour + delta * speed * 24.0 / day_length, 24.0)
	_since_update += delta
	if _since_update < UPDATE_EVERY:
		return
	_since_update = 0.0
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("time_skip"):
		hour = fposmod(hour + skip_hours, 24.0)
		_apply()


## 0 in full daylight, 1 in the dead of night; a smooth step through dusk and dawn.
func night_amount() -> float:
	return 1.0 - smoothstep(-0.14, 0.08, _sun_direction().y)


func is_night() -> bool:
	return night_amount() > 0.5


## Time as "HH:MM", for a clock.
func time_text() -> String:
	return "%02d:%02d" % [int(hour), int((hour - floorf(hour)) * 60.0)]


## Direction towards the sun: rises in the east at 6, overhead (a little south) at noon, sets at 18.
func _sun_direction() -> Vector3:
	var angle := (hour - 12.0) / 24.0 * TAU
	return Vector3(-sin(angle), cos(angle) * 0.9, 0.44).normalized()


func _apply() -> void:
	var sun_dir := _sun_direction()
	var height := sun_dir.y
	night = night_amount()
	var moon_dir := Vector3(-sun_dir.x, -sun_dir.y, sun_dir.z * 0.6 - 0.25).normalized()

	var horizon := _pick(HORIZON, height)
	_sky.set_shader_parameter("zenith", _pick(ZENITH, height))
	_sky.set_shader_parameter("horizon", horizon)
	_sky.set_shader_parameter("ground", horizon.lerp(_pick(ZENITH, height), 0.5).darkened(0.25))
	_sky.set_shader_parameter("sun_dir", sun_dir)
	_sky.set_shader_parameter("sun_color", _pick(SUN, height))
	_sky.set_shader_parameter("moon_dir", moon_dir)
	_sky.set_shader_parameter("night", night)
	_sky.set_shader_parameter("cloud_cover", _clouds)
	var lit := clampf(height * 3.0 + 0.4, 0.0, 1.0)
	_sky.set_shader_parameter("cloud_light", Color(0.78, 0.7, 0.85).lerp(Color.WHITE, lit).lerp(_pick(SUN, height), 0.3 * (1.0 - lit)))
	_sky.set_shader_parameter("cloud_shade", _pick(ZENITH, height).lerp(_pick(HORIZON, height), 0.6).lightened(0.15 * lit))

	_environment.ambient_light_color = _pick(AMBIENT, height)
	_environment.ambient_light_energy = _blend(AMBIENT_ENERGY, height)
	_environment.fog_light_color = horizon.lerp(_pick(ZENITH, height), 0.25)
	_environment.fog_density = _blend(FOG_DENSITY, height)

	_place_light(_sun, sun_dir)
	_sun.light_color = _pick(SUN, height)
	_sun.light_energy = _blend(SUN_ENERGY, height)
	_sun.shadow_enabled = height > 0.02
	_moon.light_energy = MOON_ENERGY * night
	_moon.shadow_enabled = night > 0.4
	_place_light(_moon, moon_dir)
	_follow_hero(night)


## Points a directional light so it shines from [param towards] (the direction to the source).
func _place_light(light: DirectionalLight3D, towards: Vector3) -> void:
	light.global_transform.basis = Basis.looking_at(-towards, Vector3.UP)


## The hero carries a soft light after dark, so the world around them never goes fully black.
func _follow_hero(night: float) -> void:
	if _hero_light.get_parent() == null:
		var hero := get_tree().get_first_node_in_group("player")
		if hero == null:
			return
		_hero_light.light_color = Color(0.85, 0.8, 1.0)
		_hero_light.omni_range = 14.0
		_hero_light.omni_attenuation = 1.2
		_hero_light.shadow_enabled = false
		_hero_light.position = Vector3(0.0, 2.4, 0.0)
		hero.add_child(_hero_light)
	_hero_light.light_energy = 1.1 * night
	_hero_light.visible = night > 0.02


func _pick(values: Array, at: float) -> Color:
	var left := _index_for(at)
	var right := mini(left + 1, STOPS.size() - 1)
	var span: float = STOPS[right] - STOPS[left]
	var share := 0.0 if span <= 0.0 else smoothstep(0.0, 1.0, (at - STOPS[left]) / span)
	return (values[left] as Color).lerp(values[right], share)


func _blend(values: Array, at: float) -> float:
	var left := _index_for(at)
	var right := mini(left + 1, STOPS.size() - 1)
	var span: float = STOPS[right] - STOPS[left]
	var share := 0.0 if span <= 0.0 else smoothstep(0.0, 1.0, (at - STOPS[left]) / span)
	return lerpf(values[left], values[right], share)


func _index_for(at: float) -> int:
	var found := 0
	for i in STOPS.size() - 1:
		found = i if at >= STOPS[i] else found
	return found
