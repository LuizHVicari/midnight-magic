class_name Combat
extends RefCounted
## Physics queries and damage helpers the spells share.


static func raycast(node: Node3D, from: Vector3, to: Vector3, exclude: Array[RID] = []) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to)
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
