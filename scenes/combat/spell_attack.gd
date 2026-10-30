class_name SpellAttack
extends Node
## Base of an element's basic attack. The player forwards the button of the slot to [begin] and
## [release]; subclasses decide what that means (a held charge, a single throw...). The node
## lives under the player, so [method Node._process] can drive anything that lasts.

var element: Element
var caster: Player
var ability: Ability
## Seconds left before it can be used again; basic attacks have none.
var cooldown_left := 0.0


## Button pressed.
func begin() -> void:
	pass


## Button let go.
func release() -> void:
	pass
