class_name LightFlashAction
extends AbilityAction
## Flash: the hero bursts into a blinding light. Foes close by that can see it are dazzled for a
## few seconds: they stop aiming and stumble about. Foes farther off see the light too and come
## to look, and at night that carries much farther and gets them far more worked up. A burst
## of light is no way to stay hidden.

const BLIND_RADIUS := 12.0
const BLIND_TIME := 3.0
const BACK_TURNED := 0.5  # share of the blindness left for a foe with its back to the hero
const ALERT_DAY := Vector2(35.0, 0.5)  # radius and awareness given, in daylight
const ALERT_NIGHT := Vector2(85.0, 0.9)  # and at night
const BURST_TIME := 0.3
const LIGHT_COLOR := Color(1.0, 0.95, 0.75)
const DELAY := 0.12  # lets the arm come up before the light goes off
const BODY_CENTER := 1.2


func _cast() -> bool:
	if not caster.begin_cast(Player.ANIM_THROW, 0.0, 2.2):
		return false
	caster.get_tree().create_timer(DELAY).timeout.connect(_burst)
	return true


func _burst() -> void:
	var at := caster.global_position + Vector3.UP * BODY_CENTER
	_blind_and_alert(at)
	_show(at)
	(caster.get_node("Hud") as StatsHud).flash(1.0, Color(1.0, 0.97, 0.85), 1.0, 0.8)


func _blind_and_alert(at: Vector3) -> void:
	var night := _night()
	var alert := ALERT_DAY.lerp(ALERT_NIGHT, night)
	for foe: Foe in caster.get_tree().get_nodes_in_group("foes"):
		if foe.dead:
			continue
		var distance := foe.global_position.distance_to(caster.global_position)
		if distance <= BLIND_RADIUS and _in_view(foe, at):
			foe.blind(BLIND_TIME * _facing_share(foe))
		if distance <= alert.x and not foe.is_blind():
			foe.hear_alarm(caster.global_position, alert.y, distance * 0.01)


## Whether nothing solid is between the burst and the foe's head.
func _in_view(foe: Foe, from: Vector3) -> bool:
	var health := Health.of(foe)
	var hit := Combat.raycast(foe, from, health.focus_point(), [caster.get_rid()])
	return hit.is_empty() or Health.of(hit["collider"]) == health


## Full blindness for a foe looking towards the hero, less for one that has its back turned.
func _facing_share(foe: Foe) -> float:
	var to := caster.global_position - foe.global_position
	to.y = 0.0
	var turned := foe.facing().angle_to(to)
	return BACK_TURNED if turned > deg_to_rad(100.0) else 1.0


## A burst of twinkling stars thrown out in every direction, and a big four-point flare that
## blooms and fades.
func _stars(parent: Node, at: Vector3) -> void:
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 180.0
	process.initial_velocity_min = 5.0
	process.initial_velocity_max = 15.0
	process.damping_min = 4.0
	process.damping_max = 7.0
	process.gravity = Vector3.ZERO
	process.scale_min = 0.6
	process.scale_max = 1.5
	process.scale_curve = Vfx.twinkle_curve()
	process.color_ramp = Vfx.ramp([Color(1, 1, 1, 1) * 1.8, Color(LIGHT_COLOR * 1.8, 1.0), Color(element.color, 1.0), Color(0, 0, 0, 1)])
	var burst := Vfx.particles(process, Vfx.star_quad(0.5), 70, 1.1)
	burst.local_coords = false
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.finished.connect(burst.queue_free)
	parent.add_child(burst)
	burst.global_position = at
	burst.emitting = true
	var star := Vfx.star_quad(7.0)
	var material := star.material as StandardMaterial3D
	material.albedo_color = Color(1.0, 0.95, 0.75) * 1.4
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var flare := MeshInstance3D.new()
	flare.mesh = star
	flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(flare)
	flare.global_position = at
	var tween := flare.create_tween().set_parallel()
	tween.tween_property(flare, "scale", Vector3.ONE * 2.2, 0.5).from(Vector3.ONE * 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color", Color(0, 0, 0, 1), 0.5)
	tween.chain().tween_callback(flare.queue_free)


func _night() -> float:
	var clock := caster.get_tree().get_first_node_in_group("day_night") as DayNight
	return clock.night if clock != null else 0.0


## A ball of light swelling out of the hero and a lasting glow, brighter the darker it is.
func _show(at: Vector3) -> void:
	var parent := caster.get_parent()
	var night := _night()
	Vfx.flash(parent, at, LIGHT_COLOR, lerpf(7.0, 14.0, night), BLIND_RADIUS * lerpf(2.0, 4.0, night), 0.6)
	Vfx.sparks(parent, at, element.color, 30)
	_stars(parent, at)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(LIGHT_COLOR, 1.0) * 1.6
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.material = material
	var ball := MeshInstance3D.new()
	ball.mesh = sphere
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ball.scale = Vector3.ONE * 0.3
	parent.add_child(ball)
	ball.global_position = at
	var tween := ball.create_tween().set_parallel()
	tween.tween_property(ball, "scale", Vector3.ONE * BLIND_RADIUS * 1.6, BURST_TIME).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color", Color(0.0, 0.0, 0.0, 1.0), BURST_TIME)
	tween.chain().tween_callback(ball.queue_free)
