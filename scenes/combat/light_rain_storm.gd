class_name LightRainStorm
extends Node3D
## The rain itself once it is loosed: after a short wait the lances come down over the circle one
## after another, at scattered spots, and the circle fades with them.

const WAIT := 0.7  # between letting go and the first lance
const SPREAD := 1.4  # how long the lances keep coming

var element: Element
var caster: Player
var radius := 5.0
var count := 12
var reticle: LightReticle

var _pending: Array[Dictionary] = []  # {"wait": seconds, "spot": Vector3}
var _clock := 0.0


func _ready() -> void:
	for i in count:
		_pending.append({"wait": WAIT + randf() * SPREAD, "spot": _spot()})
	reticle.fade_out(WAIT + SPREAD + 0.3)


func _process(delta: float) -> void:
	_clock += delta
	for i in range(_pending.size() - 1, -1, -1):
		if _clock < _pending[i]["wait"]:
			continue
		_drop(_pending[i]["spot"])
		_pending.remove_at(i)
	if _pending.is_empty():
		queue_free()


## A random spot on the ground inside the circle, spread evenly over its area.
func _spot() -> Vector3:
	var angle := randf() * TAU
	var reach := sqrt(randf()) * radius
	var flat := global_position + Vector3(cos(angle), 0.0, sin(angle)) * reach
	var hit := Combat.raycast(self, flat + Vector3.UP * 60.0, flat + Vector3.DOWN * 60.0)
	return hit["position"] if not hit.is_empty() else flat


func _drop(spot: Vector3) -> void:
	var lance := LightRainLance.new()
	lance.element = element
	lance.caster = caster
	lance.target = spot
	get_parent().add_child(lance)
