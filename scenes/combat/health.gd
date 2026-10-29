class_name Health
extends Node
## Hit points of anything that can be hurt. Add it as a child named "Health" of the body that
## owns the collider: spells find it with [method of]. Also tracks burning and the shadow curse,
## which tick damage on their own until they run out.

signal changed(value: float, maximum: float)
signal damaged(amount: float, element: Element)
signal burning_changed(burning: bool)
signal cursed_changed(stacks: int)
signal died

const BURN_TICK := 0.5
const CURSE_TICK := 0.5

@export var maximum := 100.0
## Height above the owner's origin that homing attacks aim at.
@export var focus_height := 1.2

var value := 0.0
var _burn_dps := 0.0
var _burn_left := 0.0
var _burn_wait := 0.0
var _burn_element: Element
var _curse_stacks := 0
var _curse_dps := 0.0  # per stack
var _curse_left := 0.0
var _curse_wait := 0.0
var _curse_element: Element


static func of(node: Node) -> Health:
	return node.get_node_or_null("Health") as Health


func _ready() -> void:
	value = maximum
	add_to_group("damageable")


func _process(delta: float) -> void:
	_tick_burn(delta)
	_tick_curse(delta)


func _tick_burn(delta: float) -> void:
	if _burn_left <= 0.0:
		return
	_burn_left -= delta
	_burn_wait -= delta
	if _burn_wait <= 0.0:
		_burn_wait += BURN_TICK
		take_damage(_burn_dps * BURN_TICK, _burn_element)
	if _burn_left <= 0.0 or not is_alive():
		_extinguish()


func _tick_curse(delta: float) -> void:
	if _curse_stacks == 0:
		return
	_curse_left -= delta
	_curse_wait -= delta
	if _curse_wait <= 0.0:
		_curse_wait += CURSE_TICK
		take_damage(_curse_dps * _curse_stacks * CURSE_TICK, _curse_element)
	if _curse_left <= 0.0 or not is_alive():
		_lift_curse()


func is_alive() -> bool:
	return value > 0.0


func is_burning() -> bool:
	return _burn_left > 0.0


func curse_stacks() -> int:
	return _curse_stacks


## World position homing attacks steer towards.
func focus_point() -> Vector3:
	return (get_parent() as Node3D).global_position + Vector3.UP * focus_height


func take_damage(amount: float, element: Element = null) -> void:
	if not is_alive():
		return
	value = maxf(value - amount, 0.0)
	damaged.emit(amount, element)
	changed.emit(value, maximum)
	if value <= 0.0:
		died.emit()


## Sets the target on fire; a stronger or longer burn replaces a weaker one.
func ignite(dps: float, duration: float, element: Element = null) -> void:
	if not is_alive():
		return
	var was_burning := is_burning()
	_burn_dps = maxf(_burn_dps, dps)
	_burn_left = maxf(_burn_left, duration)
	_burn_element = element
	if not was_burning:
		_burn_wait = BURN_TICK
		burning_changed.emit(true)


## Adds a stack of curse (up to [param max_stacks]); every stack ticks [param dps_per_stack]
## and each new stack restarts the timer.
func curse(dps_per_stack: float, duration: float, max_stacks: int, element: Element = null) -> void:
	if not is_alive():
		return
	var before := _curse_stacks
	_curse_stacks = mini(_curse_stacks + 1, max_stacks)
	_curse_dps = maxf(_curse_dps, dps_per_stack)
	_curse_left = duration
	_curse_element = element
	if before == 0:
		_curse_wait = CURSE_TICK
	if _curse_stacks != before:
		cursed_changed.emit(_curse_stacks)


func restore() -> void:
	value = maximum
	_extinguish()
	_lift_curse()
	changed.emit(value, maximum)


func _extinguish() -> void:
	var was_burning := is_burning() or _burn_dps > 0.0
	_burn_left = 0.0
	_burn_dps = 0.0
	if was_burning:
		burning_changed.emit(false)


func _lift_curse() -> void:
	var had := _curse_stacks > 0
	_curse_stacks = 0
	_curse_dps = 0.0
	_curse_left = 0.0
	if had:
		cursed_changed.emit(0)
