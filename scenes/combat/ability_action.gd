class_name AbilityAction
extends SpellAttack
## Base of an ability's behavior. It owns the cooldown and the mana check, so a subclass only
## says what happens on [method _cast]: it returns true if the spell really went off (and the
## cost is paid and the cooldown starts), false if something stopped it (busy, nothing to aim at).
## Spells that last or charge override [method _update] for their per-frame work.


## Spells that last or charge turn this off and start the cooldown themselves, when they end.
var cooldown_on_cast := true


func begin() -> void:
	if not is_ready():
		return
	if _cast():
		caster.spend_mana(ability.cost)
		if cooldown_on_cast:
			cooldown_left = ability.cooldown


## Off cooldown and enough mana.
func is_ready() -> bool:
	return cooldown_left <= 0.0 and caster.mana >= ability.cost


func _process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)
	_update(delta)


func _cast() -> bool:
	return false


func _update(_delta: float) -> void:
	pass
