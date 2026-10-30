class_name LightRainAction
extends AbilityAction
## Rain of lances: hold to mark a circle of light on the ground where you aim. The longer you hold
## the wider it grows, and the faster it drinks mana. Let go and, after a moment, lances of light
## fall all over it. A small area is cheap and quick; a big one costs a lot but covers a whole
## camp. The circle follows the aim while it grows, so it can be steered.

const MIN_RADIUS := 2.5
const MAX_RADIUS := 10.0
const GROW_TIME := 3.0  # seconds of holding to reach the full size
const MAX_HOLD := 6.0
const MAX_REACH := 45.0  # how far from the hero the circle can be put
## Mana per second while holding: at the start, and once it is full size.
const DRAIN := Vector2(4.0, 22.0)
const LANCES_PER_SQUARE_METER := 0.16
const MIN_LANCES := 6
const RELEASE_LOCK := 0.4

var _holding := false
var _held := 0.0
var _reticle: LightReticle


func _init() -> void:
	cooldown_on_cast = false  # the wait starts when the rain is loosed, not while aiming


func _cast() -> bool:
	if not caster.begin_cast(Player.ANIM_CHANNEL, INF, 1.6, Player.CHANNEL_HOLD):
		return false
	_holding = true
	_held = 0.0
	_reticle = LightReticle.new()
	_reticle.set_color(element.color)
	caster.get_parent().add_child(_reticle)
	_aim_reticle(MIN_RADIUS)
	return true


func release() -> void:
	if _holding:
		_loose()


func _update(delta: float) -> void:
	if not _holding:
		return
	_held += delta
	var growth := clampf(_held / GROW_TIME, 0.0, 1.0)
	var drain := lerpf(DRAIN.x, DRAIN.y, growth) * delta
	if _held >= MAX_HOLD or not caster.spend_mana(drain):
		_loose()
		return
	_aim_reticle(lerpf(MIN_RADIUS, MAX_RADIUS, growth))


func _radius() -> float:
	return lerpf(MIN_RADIUS, MAX_RADIUS, clampf(_held / GROW_TIME, 0.0, 1.0))


func _center() -> Vector3:
	var aim := caster.aim_point()
	var away := aim - caster.global_position
	return aim if away.length() <= MAX_REACH else caster.global_position + away.normalized() * MAX_REACH


func _aim_reticle(radius: float) -> void:
	_reticle.global_position = _center()
	_reticle.set_radius(radius)


func _loose() -> void:
	_holding = false
	caster.release_cast(Player.ANIM_THROW, RELEASE_LOCK, 1.8)
	cooldown_left = ability.cooldown
	var radius := _radius()
	var storm := LightRainStorm.new()
	storm.element = element
	storm.caster = caster
	storm.radius = radius
	storm.count = maxi(MIN_LANCES, roundi(PI * radius * radius * LANCES_PER_SQUARE_METER))
	storm.reticle = _reticle
	storm.position = _center()
	caster.get_parent().add_child(storm)
	_reticle = null
