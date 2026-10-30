class_name FireCombustionAction
extends AbilityAction
## Combustion: sets off everything that is burning. Every burning creature within reach blows up
## at once, for a good hit plus several times what its burn had left to do, and the fire goes out
## on it. Nothing happens, and nothing is spent, if nothing is burning, so it is the payoff for
## the flamethrower, the wall and the aura rather than an attack of its own.

const REACH := 30.0
const BASE_DAMAGE := 20.0
const BURN_MULTIPLIER := 3.0  # times the damage the burn still had to do
const BLAST_SHOVE := 7.0
const DELAY := 0.1
const FIRE := Color(1.0, 0.5, 0.2)
const SHOCKWAVE := preload("res://assets/shaders/shockwave.gdshader")


func _cast() -> bool:
	if _burning().is_empty():
		return false
	if not caster.begin_cast(Player.ANIM_THROW, 0.0, 2.4):
		return false
	caster.get_tree().create_timer(DELAY).timeout.connect(_detonate)
	return true


func _burning() -> Array[Health]:
	var found: Array[Health] = []
	for health: Health in caster.get_tree().get_nodes_in_group("damageable"):
		var reach := health.focus_point().distance_to(caster.global_position)
		if health.is_alive() and health.is_burning() and reach <= REACH:
			found.append(health)
	return found


func _detonate() -> void:
	for health in _burning():
		var at := health.focus_point()
		var damage := BASE_DAMAGE + health.burn_remaining() * BURN_MULTIPLIER
		health.douse()
		health.take_damage(damage, element)
		var away := (at - caster.global_position) * Vector3(1.0, 0.0, 1.0)
		health.push((away.normalized() + Vector3.UP * 0.6) * BLAST_SHOVE)
		_blast(at)


func _blast(at: Vector3) -> void:
	var parent := caster.get_parent()
	Vfx.flash(parent, at, FIRE, 6.0, 12.0, 0.3)
	Vfx.sparks(parent, at, FIRE, 22)
	var material := ShaderMaterial.new()
	material.shader = SHOCKWAVE
	material.set_shader_parameter("color", Vector3(FIRE.r, FIRE.g, FIRE.b))
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 14
	sphere.rings = 7
	sphere.material = material
	var wave := MeshInstance3D.new()
	wave.mesh = sphere
	wave.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wave.scale = Vector3.ONE * 0.5
	parent.add_child(wave)
	wave.global_position = at
	var tween := wave.create_tween().set_parallel()
	tween.tween_property(wave, "scale", Vector3.ONE * 5.0, 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(value: float) -> void: material.set_shader_parameter("fade", value), 1.0, 0.0, 0.3)
	tween.chain().tween_callback(wave.queue_free)
