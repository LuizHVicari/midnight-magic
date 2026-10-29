class_name LightAttack
extends SpellAttack
## Light: a volley of lances. Holding the button conjures lances that hover around the hero at
## scattered points; letting go looses them in a quick burst that bends a little towards the
## nearest target. Cheap, with no cooldown: tapping fires a lance or two, holding builds a storm.

const MAX_LANCES := 12
const CONJURE_EVERY := 0.1
const COST := 1.5
const BURST_GAP := 0.045
const BURST_DELAY := 0.15  # lets the throwing pose start before the first lance leaves
const RELEASE_LOCK := 0.35

var _holding := false
var _timer := 0.0
var _slots := 0
var _hovering: Array[LightLance] = []
var _launching: Array[Dictionary] = []  # {"lance": LightLance, "wait": seconds}


func begin() -> void:
	if caster.mana < COST or not caster.begin_cast(Player.ANIM_CHANNEL, INF, 1.6, Player.CHANNEL_HOLD):
		return
	_holding = true
	_timer = 0.0


func release() -> void:
	if not _holding:
		return
	_holding = false
	if _hovering.is_empty():
		caster.end_cast()
		return
	caster.release_cast(Player.ANIM_THROW, RELEASE_LOCK, 2.0)
	for i in _hovering.size():
		_launching.append({"lance": _hovering[i], "wait": BURST_DELAY + i * BURST_GAP})
	_hovering.clear()


func _process(delta: float) -> void:
	if not _holding and _hovering.is_empty() and _launching.is_empty():
		return
	var aim := caster.aim_point()
	_conjure(delta)
	_follow(aim)
	_fire_due(delta, aim)


func _conjure(delta: float) -> void:
	_timer -= delta
	var room := _hovering.size() < MAX_LANCES
	# spend_mana is last so mana only goes when a lance really appears.
	if not _holding or _timer > 0.0 or not room or not caster.spend_mana(COST):
		return
	_timer = CONJURE_EVERY
	var lance := LightLance.new()
	lance.element = element
	lance.caster = caster
	lance.slot = _slot(_slots)
	_slots += 1
	caster.get_parent().add_child(lance)
	lance.hover(caster.global_position, caster.camera_pivot.rotation.y, caster.aim_point())
	_hovering.append(lance)


func _follow(aim: Vector3) -> void:
	var yaw := caster.camera_pivot.rotation.y
	for lance in _hovering:
		lance.hover(caster.global_position, yaw, aim)
	for entry in _launching:
		var queued: LightLance = entry["lance"]
		queued.hover(caster.global_position, yaw, aim)


func _fire_due(delta: float, aim: Vector3) -> void:
	for i in range(_launching.size() - 1, -1, -1):
		_launching[i]["wait"] -= delta
		if _launching[i]["wait"] > 0.0:
			continue
		var lance: LightLance = _launching[i]["lance"]
		lance.launch(aim)
		_launching.remove_at(i)


## Scatters lances over a fan above and behind the shoulders, never twice in the same place.
func _slot(n: int) -> Vector3:
	var spread := fposmod(n * 0.618034, 1.0)
	var angle := deg_to_rad(lerpf(-80.0, 80.0, spread))
	var ring := 1.3 + 0.5 * float(n % 2)
	return Vector3(sin(angle) * ring, 1.5 + cos(angle) * ring * 0.9, 0.5)
