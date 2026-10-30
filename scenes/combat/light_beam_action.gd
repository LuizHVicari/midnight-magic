class_name LightBeamAction
extends AbilityAction
## Light beam: the hero turns into a streak of light and shoots along the aim, going through
## whatever is on the way and hurting it, and steps out of it again at the far end. Cannot be
## hurt in between. It stops short of walls and never ends inside a creature: it comes out
## behind the last one it went through. A way to cross ground as much as an attack.

const RANGE := 24.0
const MIN_DISTANCE := 3.0
const TIME := 0.22
const DAMAGE := 40.0
const HIT_RADIUS := 1.8
const BODY_CENTER := 1.0  # the hero's middle above their feet; the path is traced from there
const CLEARANCE := 0.45
## How close to the end of the path a creature must be for the hero to come out behind it, and
## how far behind it.
const LANDING_RADIUS := 1.4
const BEHIND := 1.7
const GLOW_COLOR := Color(1.0, 0.9, 0.6)
const FADE_TIME := 0.3

var _trail: Node3D
var _start := Vector3.ZERO
var _active := false
var _fade := 0.0
var _victims: Array[Dictionary] = []  # {"health": Health, "at": 0..1 along the path}


func _cast() -> bool:
	var origin := caster.global_position + Vector3.UP * BODY_CENTER
	var direction := -caster.camera.global_basis.z
	var reach := _free_distance(origin, direction, RANGE)
	reach = _land_behind_creatures(origin, direction, reach)
	if reach < MIN_DISTANCE:
		return false
	var end := origin + direction * reach
	if not caster.begin_dash(end - Vector3.UP * BODY_CENTER, TIME):
		return false
	_start = origin
	_victims = _targets(origin, end)
	_active = true
	_fade = 0.0
	_trail = _make_trail()
	caster.get_parent().add_child(_trail)
	Vfx.sparks(caster.get_parent(), origin, element.color, 16)
	Vfx.flash(caster.get_parent(), origin, GLOW_COLOR, 4.0, 12.0, 0.3)
	return true


## How far the hero's middle can travel along [param direction], up to [param limit], before it
## would hit the world. Creatures do not count: the beam goes through them.
func _free_distance(origin: Vector3, direction: Vector3, limit: float) -> float:
	var shape := SphereShape3D.new()
	shape.radius = CLEARANCE
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, origin)
	query.motion = direction * limit
	query.collision_mask = Combat.WORLD | Combat.STONE
	query.exclude = _creature_bodies()
	query.exclude.append(caster.get_rid())
	var fractions := caster.get_world_3d().direct_space_state.cast_motion(query)
	return limit * fractions[0] - 0.2


func _creature_bodies() -> Array[RID]:
	var bodies: Array[RID] = []
	for health: Health in caster.get_tree().get_nodes_in_group("damageable"):
		var body := health.get_parent() as CollisionObject3D
		if body != null:
			bodies.append(body.get_rid())
	return bodies


## If the path would end on top of a creature, carries on past the last of them, as far as the
## world allows.
func _land_behind_creatures(origin: Vector3, direction: Vector3, reach: float) -> float:
	var farthest := -1.0
	for health: Health in caster.get_tree().get_nodes_in_group("damageable"):
		var offset := health.focus_point() - origin
		var along := offset.dot(direction)
		var aside := (offset - direction * along).length()
		if aside <= LANDING_RADIUS and absf(along - reach) <= BEHIND:
			farthest = maxf(farthest, along)
	if farthest < 0.0:
		return reach
	var wanted := farthest + BEHIND
	return minf(wanted, _free_distance(origin, direction, wanted))


## Everything alive near the path, with how far along it they are, so each is hit as the hero
## passes.
func _targets(from: Vector3, to: Vector3) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var line := to - from
	for health: Health in caster.get_tree().get_nodes_in_group("damageable"):
		var offset := health.focus_point() - from
		var along := clampf(offset.dot(line) / line.length_squared(), 0.0, 1.0)
		if offset.distance_to(line * along) <= HIT_RADIUS:
			found.append({"health": health, "at": along})
	return found


func _update(delta: float) -> void:
	if _trail == null:
		return
	if caster.dashing:
		_strike_passed(caster.dash_progress())
		_stretch_trail(caster.global_position + Vector3.UP * BODY_CENTER)
		return
	if _active:
		_arrive()
	_fade += delta
	LightStreak.set_fade(_trail, 1.0 - clampf(_fade / FADE_TIME, 0.0, 1.0))
	if _fade >= FADE_TIME:
		_trail.queue_free()
		_trail = null


func _strike_passed(progress: float) -> void:
	for i in range(_victims.size() - 1, -1, -1):
		if _victims[i]["at"] > progress:
			continue
		var health: Health = _victims[i]["health"]
		_victims.remove_at(i)
		if not is_instance_valid(health):
			continue
		health.take_damage(DAMAGE, element)
		Vfx.sparks(caster.get_parent(), health.focus_point(), element.color, 10)


func _arrive() -> void:
	_active = false
	_strike_passed(1.0)
	var at := caster.global_position + Vector3.UP * BODY_CENTER
	Vfx.sparks(caster.get_parent(), at, element.color, 16)
	Vfx.flash(caster.get_parent(), at, GLOW_COLOR, 4.0, 12.0, 0.3)


## Head at the hero's current spot, the body of the streak reaching back to where it began.
func _stretch_trail(head: Vector3) -> void:
	var length := head.distance_to(_start)
	if length < 0.05:
		return
	_trail.global_position = head
	_trail.look_at(head + (head - _start))
	_trail.scale = Vector3(1.0, 1.0, length)


func _make_trail() -> Node3D:
	var root := Node3D.new()
	root.add_child(LightStreak.layer(0.4, 0.4, 1.0, 0.0, element.color, 1.2, 0.8, 1.0, 0.0, 0.5, 0.0))
	root.add_child(LightStreak.layer(0.14, 0.14, 1.0, 0.0, element.color, 1.8, 1.0, 0.8, 0.0, 1.0, 0.0))
	return root
