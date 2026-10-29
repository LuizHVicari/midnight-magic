class_name NightLight
extends OmniLight3D
## A lamp or fire that comes on as night falls and goes out at dawn, following [DayNight]. Without
## a day-night clock in the scene it just stays off. Fires flicker.

var strength := 2.0
var flicker := 0.0
var _day_night: DayNight
var _phase := randf() * TAU


static func make(color: Color, energy: float, reach: float, flickers := false) -> NightLight:
	var light := NightLight.new()
	light.light_color = color
	light.strength = energy
	light.omni_range = reach
	light.omni_attenuation = 1.3
	light.shadow_enabled = false
	light.flicker = 0.25 if flickers else 0.0
	light.visible = false
	return light


func _process(_delta: float) -> void:
	if _day_night == null:
		_day_night = get_tree().get_first_node_in_group("day_night") as DayNight
	var night := _day_night.night if _day_night != null else 0.0
	visible = night > 0.03
	if not visible:
		return
	var time := Time.get_ticks_msec() / 1000.0
	var wobble := sin(time * 11.0 + _phase) * 0.5 + sin(time * 23.0 + _phase * 2.0) * 0.5
	light_energy = strength * night * (1.0 + flicker * wobble)
