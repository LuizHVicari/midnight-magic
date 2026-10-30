class_name LightRainLance
extends Node3D
## One lance of the rain: a streak of light that drops from high above onto a spot and bursts
## there, hurting everything close to it.

const SPEED := 80.0
const HEIGHT := 30.0
const LENGTH := 4.5
const DAMAGE := 14.0
const SPLASH := 1.4

var element: Element
var caster: Player
## The spot on the ground it lands on.
var target := Vector3.ZERO


func _ready() -> void:
	add_child(LightStreak.layer(0.2, 0.0, LENGTH, 0.0, element.color, 1.2, 0.8, 1.0, 0.6, 0.5, 0.03))
	add_child(LightStreak.layer(0.07, 0.0, LENGTH * 0.9, 0.0, element.color, 1.8, 1.0, 0.8, 0.7, 1.0, 0.01))
	position = target + Vector3.UP * HEIGHT
	look_at(target, Vector3.RIGHT)  # tip first, straight down


func _physics_process(delta: float) -> void:
	global_position.y -= SPEED * delta
	if global_position.y > target.y:
		return
	global_position = target
	Combat.blast(self, target + Vector3.UP * 0.3, SPLASH, DAMAGE, element, [caster.get_rid()], 0.5)
	Vfx.sparks(get_parent(), target, element.color, 8)
	Vfx.flash(get_parent(), target + Vector3.UP * 0.4, Color(1.0, 0.9, 0.6), 2.0, 6.0, 0.18)
	queue_free()
