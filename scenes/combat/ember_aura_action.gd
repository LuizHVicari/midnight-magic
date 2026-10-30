class_name EmberAuraAction
extends AbilityAction
## Ember aura: wraps the hero in a ring of embers for a while. Everything that comes within a few
## meters burns, so it punishes foes that close in. Using it again while it lasts renews it.

var _aura: EmberAura


func _cast() -> bool:
	if _aura != null and is_instance_valid(_aura):
		_aura.refresh()
		return true
	_aura = EmberAura.new()
	_aura.element = element
	_aura.caster = caster
	caster.add_child(_aura)
	return true
