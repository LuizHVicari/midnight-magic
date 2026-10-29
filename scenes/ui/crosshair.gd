class_name Crosshair
extends Control
## Aiming mark in the middle of the screen: a small dot inside a ring broken into four arcs,
## cream with a dark outline so it reads on bright sky, dark ground and water alike. The camera
## looks through this point, so it is exactly where spells are aimed.

const COLOR := Color(1.0, 0.96, 0.85)
const OUTLINE := Color(0.12, 0.08, 0.2, 0.7)
const RADIUS := 9.0
const ARC := deg_to_rad(52.0)
const WIDTH := 2.0
const DOT := 2.2


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A CanvasLayer is no Control, so there is no parent rect to anchor to: follow the window.
	get_viewport().size_changed.connect(queue_redraw)


func _draw() -> void:
	var center := (get_viewport_rect().size * 0.5).round()
	draw_circle(center, DOT + 1.2, OUTLINE)
	for corner in 4:
		var middle := PI / 4.0 + corner * PI / 2.0
		draw_arc(center, RADIUS, middle - ARC * 0.5, middle + ARC * 0.5, 10, OUTLINE, WIDTH + 2.4, true)
	draw_circle(center, DOT, COLOR)
	for corner in 4:
		var middle := PI / 4.0 + corner * PI / 2.0
		draw_arc(center, RADIUS, middle - ARC * 0.5, middle + ARC * 0.5, 10, COLOR, WIDTH, true)
