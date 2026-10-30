class_name Ability
extends Resource
## One spell of an element's kit, the basic attack included. The data here is what the HUD, the
## wheel and the cost checks read; what the spell does lives in the [SpellAttack] script it
## points to (an [AbilityAction] when it has a cost and a cooldown of its own). Elements list their abilities; the hero unlocks them as the game goes on.

@export var display_name := ""
@export_multiline var description := ""
## Picture for the quick slots and the wheel; without one the slot shows the name's initial.
@export var icon: Texture2D
@export var cost := 20.0
## Seconds before it can be used again, counted from the moment it is cast.
@export var cooldown := 5.0
## Hero level that unlocks it.
@export var unlock_level := 1
@export var action_script: GDScript


func create_action(element: Element) -> SpellAttack:
	var action: SpellAttack = action_script.new()
	action.ability = self
	action.element = element
	return action
