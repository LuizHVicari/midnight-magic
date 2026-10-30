class_name WindBreezeAction
extends AbilityAction
## Breeze cloak: wraps the hero in a light wind for a while. Footsteps nearly vanish, so foes hear
## far less of them, and the hero walks and runs faster. The cloak shows as a whirl of wind with
## leaves and twinkling stars circling in it.

const DURATION := 12.0

var _aura := BreezeAura.new()


func _ready() -> void:
	caster.add_child(_aura)


func _cast() -> bool:
	caster.breeze_left = DURATION
	return true


func _update(_delta: float) -> void:
	_aura.set_active(caster.breeze_left > 0.0)
