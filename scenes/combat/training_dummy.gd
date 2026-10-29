class_name TrainingDummy
extends StaticBody3D
## Straw-and-wood target to try spells on until there are real enemies: shows every hit as a
## floating number, catches fire, falls over when it runs out of health and stands back up.

const WOOD := Color(0.5, 0.35, 0.2)
const STRAW := Color(0.85, 0.74, 0.45)
const REVIVE_AFTER := 3.0

@export var max_health := 300.0

var _health := Health.new()
var _pivot := Node3D.new()
var _label := Label3D.new()
var _flames: GPUParticles3D
var _curse_aura: GPUParticles3D
var _materials: Array[StandardMaterial3D] = []
var _collider := CollisionShape3D.new()


func _ready() -> void:
	_build()
	_health.name = "Health"
	_health.maximum = max_health
	add_child(_health)
	_health.changed.connect(_on_changed)
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)
	_health.burning_changed.connect(func(burning: bool) -> void: _flames.emitting = burning)
	_health.cursed_changed.connect(_on_cursed)
	_on_changed(max_health, max_health)


func _build() -> void:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.5
	capsule.height = 2.3
	_collider.shape = capsule
	_collider.position.y = 1.15
	add_child(_collider)
	add_child(_pivot)

	var post := CylinderMesh.new()
	post.top_radius = 0.2
	post.bottom_radius = 0.26
	post.height = 2.0
	_part(post, WOOD, Vector3(0.0, 1.0, 0.0))
	var arm := BoxMesh.new()
	arm.size = Vector3(1.5, 0.16, 0.16)
	_part(arm, WOOD, Vector3(0.0, 1.5, 0.0))
	var head := SphereMesh.new()
	head.radius = 0.3
	head.height = 0.6
	_part(head, STRAW, Vector3(0.0, 2.25, 0.0))
	var base := CylinderMesh.new()
	base.top_radius = 0.6
	base.bottom_radius = 0.6
	base.height = 0.15
	_part(base, WOOD, Vector3(0.0, 0.07, 0.0))

	_label.position.y = 3.0
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 36
	_label.pixel_size = 0.005
	_label.outline_size = 8
	add_child(_label)

	_flames = FireVfx.flames(0.35, 22, 0.7, 0.22)
	_flames.position.y = 1.2
	_flames.emitting = false
	add_child(_flames)

	_curse_aura = ShadowVfx.curse_aura()
	_curse_aura.position.y = 1.2
	add_child(_curse_aura)


func _part(mesh: Mesh, color: Color, at: Vector3) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color.BLACK
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	_pivot.add_child(instance)
	_materials.append(material)


## The aura thickens with every stack of curse.
func _on_cursed(stacks: int) -> void:
	_curse_aura.emitting = stacks > 0
	_curse_aura.amount_ratio = clampf(stacks / 3.0, 0.34, 1.0)


func _on_changed(value: float, maximum: float) -> void:
	_label.text = "%d / %d" % [ceili(value), roundi(maximum)]


func _on_damaged(amount: float, element: Element) -> void:
	var color := element.color if element else Color.WHITE
	DamagePopup.spawn(self, global_position + Vector3(randf_range(-0.3, 0.3), 2.8, randf_range(-0.3, 0.3)), str(roundi(amount)), color)
	_flash(color)


## Brief glow in the element's color and a little wobble.
func _flash(color: Color) -> void:
	var tween := create_tween().set_parallel()
	for material in _materials:
		material.emission = color * 0.6
		tween.tween_property(material, "emission", Color.BLACK, 0.2)
	_pivot.rotation.x = -0.1
	tween.tween_property(_pivot, "rotation:x", 0.0, 0.25).set_trans(Tween.TRANS_ELASTIC)


func _on_died() -> void:
	_collider.set_deferred("disabled", true)
	var tween := create_tween()
	tween.tween_property(_pivot, "rotation:x", -PI * 0.5, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_interval(REVIVE_AFTER)
	tween.tween_callback(_revive)


func _revive() -> void:
	_collider.disabled = false
	_pivot.rotation.x = 0.0
	_health.restore()
