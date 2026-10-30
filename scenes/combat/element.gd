class_name Element
extends Resource
## One of the magic elements. The data here is what the HUD and the effects read; how the
## element's basic attack plays out lives in the [SpellAttack] script it points to.

@export var display_name := ""
@export var color := Color.WHITE
## What the hero's robe and cape turn into while this element is equipped.
@export var robe := Color(0.35, 0.3, 0.8)
@export var cape := Color(0.8, 0.15, 0.5)
## Extra damage against soaked targets (0.5 = +50%): lets light conduct through water.
@export var wet_bonus := 0.0
@export var attack_script: GDScript


func create_attack() -> SpellAttack:
	var attack: SpellAttack = attack_script.new()
	attack.element = self
	return attack
