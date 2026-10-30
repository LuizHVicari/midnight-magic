class_name Combat
extends RefCounted
## Physics queries and damage helpers the spells share.


## Physics layers: 1 is the world and everything spells can hit; 2 is stone cover that bodies bump
## into but spells fly through.
const WORLD := 1
const STONE := 2


## Ray that only sees [constant WORLD], so spells pass through stone cover.
static func raycast(node: Node3D, from: Vector3, to: Vector3, exclude: Array[RID] = []) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, WORLD)
	query.exclude = exclude
	return node.get_world_3d().direct_space_state.intersect_ray(query)


## Hurts whatever owns [param collider], if it has a [Health]. Returns whether it did.
static func hurt(collider: Node, amount: float, element: Element) -> Health:
	var health := Health.of(collider)
	if health != null:
		health.take_damage(amount, element)
	return health


## Damage in a sphere, strongest at the center and fading to [param edge] of it at the rim.
## Returns the [Health]s that were hit.
static func blast(
	node: Node3D,
	center: Vector3,
	radius: float,
	damage: float,
	element: Element,
	exclude: Array[RID] = [],
	edge := 0.4,
) -> Array[Health]:
	var shape := SphereShape3D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, center)
	query.exclude = exclude
	var struck: Array[Health] = []
	for result in node.get_world_3d().direct_space_state.intersect_shape(query, 32):
		var health := Health.of(result["collider"])
		if health == null or struck.has(health):
			continue
		var reach := clampf(center.distance_to(health.focus_point()) / radius, 0.0, 1.0)
		health.take_damage(damage * lerpf(1.0, edge, reach), element)
		struck.append(health)
	return struck


## How dark it is now (0 in daylight, 1 at night), or 0 when the world has no clock.
static func night_amount(tree: SceneTree) -> float:
	var clock := tree.get_first_node_in_group("day_night") as DayNight
	return clock.night if clock != null else 0.0


## Bodies of everything that has [Health], so rays and sweeps can pass through creatures.
static func creature_bodies(tree: SceneTree) -> Array[RID]:
	var bodies: Array[RID] = []
	for health: Health in tree.get_nodes_in_group("damageable"):
		var body := health.get_parent() as CollisionObject3D
		if body != null:
			bodies.append(body.get_rid())
	return bodies


## How far a ball of [param radius] can travel from [param origin] along [param direction], up to
## [param limit], before it would touch the world or stone cover.
static func free_distance(node: Node3D, origin: Vector3, direction: Vector3, limit: float, radius: float, exclude: Array[RID] = []) -> float:
	var shape := SphereShape3D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, origin)
	query.motion = direction * limit
	query.collision_mask = WORLD | STONE
	query.exclude = exclude
	var fractions := node.get_world_3d().direct_space_state.cast_motion(query)
	return limit * fractions[0]


## Closest-to-the-line living target inside a cone, for attacks that bend a little towards it.
static func find_target(node: Node, origin: Vector3, direction: Vector3, reach: float, cone_deg: float) -> Health:
	var best: Health = null
	var best_angle := deg_to_rad(cone_deg)
	for candidate: Health in node.get_tree().get_nodes_in_group("damageable"):
		var offset := candidate.focus_point() - origin
		var angle := direction.angle_to(offset)
		if not candidate.is_alive() or offset.length() > reach or angle >= best_angle:
			continue
		best = candidate
		best_angle = angle
	return best


## Living targets inside a cone, each with its distance, that are not hidden behind something.
## The cone opens from [param origin] along [param direction] to [param reach] meters and
## [param half_angle_deg] either side.
static func in_cone(node: Node3D, origin: Vector3, direction: Vector3, reach: float, half_angle_deg: float, exclude: Array[RID] = []) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for candidate: Health in node.get_tree().get_nodes_in_group("damageable"):
		var point := candidate.focus_point()
		var offset := point - origin
		if not candidate.is_alive() or offset.length() > reach or direction.angle_to(offset) > deg_to_rad(half_angle_deg):
			continue
		var blocker := raycast(node, origin, point, exclude)
		if not blocker.is_empty() and blocker["collider"] != candidate.get_parent():
			continue
		found.append({"health": candidate, "distance": offset.length(), "offset": offset})
	return found


## Living targets along a thick beam, each with its distance, that are not hidden behind something.
## The beam is [param base_radius] wide at [param origin] and opens by [param half_angle_deg] as
## it goes, up to [param reach]. Unlike [method in_cone] it still catches a target close in front
## of the caster, whose single focus point sits far off a narrow cone's axis.
static func in_beam(node: Node3D, origin: Vector3, direction: Vector3, reach: float, base_radius: float, half_angle_deg: float, exclude: Array[RID] = []) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var spread := tan(deg_to_rad(half_angle_deg))
	for candidate: Health in node.get_tree().get_nodes_in_group("damageable"):
		var point := candidate.focus_point()
		var offset := point - origin
		var along := offset.dot(direction)
		if not candidate.is_alive() or along < 0.0 or along > reach:
			continue
		if (offset - direction * along).length() > base_radius + along * spread:
			continue
		var blocker := raycast(node, origin, point, exclude)
		if not blocker.is_empty() and blocker["collider"] != candidate.get_parent():
			continue
		found.append({"health": candidate, "distance": along, "offset": offset})
	return found
