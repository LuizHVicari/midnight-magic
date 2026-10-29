class_name Health
extends Node
## Hit points of anything that can be hurt. Add it as a child named "Health" of the body that
## owns the collider: spells find it with [method of]. Also tracks burning, which ticks damage
## on its own until it runs out.

signal changed(value: float, maximum: float)
signal damaged(amount: float, element: Element)
signal burning_changed(burning: bool)
signal died

const BURN_TICK := 0.5

@export var maximum := 100.0
## Height above the owner's origin that homing attacks aim at.
@export var focus_height := 1.2

var value := 0.0
var _burn_dps := 0.0
var _burn_left := 0.0
var _burn_wait := 0.0
var _burn_element: Element


static func of(node: Node) -> Health:
	return node.get_node_or_null("Health") as Health


func _ready() -> void:
	value = maximum
	add_to_group("damageable")


func _process(delta: float) -> void:
	if _burn_left <= 0.0:
		return
	_burn_left -= delta
	_burn_wait -= delta
	if _burn_wait <= 0.0:
		_burn_wait += BURN_TICK
		take_damage(_burn_dps * BURN_TICK, _burn_element)
	if _burn_left <= 0.0 or not is_alive():
		_extinguish()


func is_alive() -> bool:
	return value > 0.0


func is_burning() -> bool:
	return _burn_left > 0.0


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


func restore() -> void:
	value = maximum
	_extinguish()
	changed.emit(value, maximum)


func _extinguish() -> void:
	var was_burning := is_burning() or _burn_dps > 0.0
	_burn_left = 0.0
	_burn_dps = 0.0
	if was_burning:
		burning_changed.emit(false)
