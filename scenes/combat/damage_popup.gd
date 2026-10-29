class_name DamagePopup
extends Label3D
## Floating number that rises and fades where something got hurt.


static func spawn(parent: Node, at: Vector3, text: String, color: Color) -> void:
	var popup := DamagePopup.new()
	popup.text = text
	popup.modulate = color
	popup.outline_modulate = Color(0.1, 0.05, 0.15)
	popup.outline_size = 10
	popup.font_size = 40
	popup.pixel_size = 0.006
	popup.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	popup.no_depth_test = true
	parent.add_child(popup)
	popup.global_position = at
	var tween := popup.create_tween().set_parallel()
	tween.tween_property(popup, "position:y", popup.position.y + 1.3, 0.8).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tween.chain().tween_callback(popup.queue_free)
