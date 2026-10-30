class_name LightOrbAction
extends AbilityAction
## Sentinel orb: calls a small sun that floats beside the hero for a while, lighting the area and
## shooting at foes that are fighting. Calling it again while it lasts only renews it.

var _sentinel: LightSentinel


func _cast() -> bool:
	if _sentinel != null and is_instance_valid(_sentinel):
		_sentinel.refresh()
		return true
	_sentinel = LightSentinel.new()
	_sentinel.element = element
	_sentinel.caster = caster
	caster.get_parent().add_child(_sentinel)
	return true
