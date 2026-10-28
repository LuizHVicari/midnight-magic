class_name PathUtil
## Helpers for 2D polylines (x, z): smoothing, resampling, moving averages and distances.


## Catmull-Rom curve through [points], resampled every [spacing] meters.
static func smooth(points: PackedVector2Array, spacing := 3.0) -> PackedVector2Array:
	var dense := PackedVector2Array()
	var last := points.size() - 1
	for i in last:
		var p0 := points[maxi(i - 1, 0)]
		var p1 := points[i]
		var p2 := points[i + 1]
		var p3 := points[mini(i + 2, last)]
		var steps := maxi(int(p1.distance_to(p2)), 1)
		for s in steps:
			dense.append(_catmull(p0, p1, p2, p3, float(s) / steps))
	dense.append(points[last])
	return resample(dense, spacing)


## Points exactly [spacing] meters apart along the polyline (the last one may be closer).
static func resample(poly: PackedVector2Array, spacing: float) -> PackedVector2Array:
	var out := PackedVector2Array([poly[0]])
	var carried := 0.0
	for i in poly.size() - 1:
		var a := poly[i]
		var b := poly[i + 1]
		var seg := a.distance_to(b)
		if seg < 0.001:
			continue
		var pos := 0.0
		while carried + seg - pos >= spacing:
			pos += spacing - carried
			out.append(a.lerp(b, pos / seg))
			carried = 0.0
		carried += seg - pos
	var end := poly[poly.size() - 1]
	if out[out.size() - 1].distance_to(end) > spacing * 0.3:
		out.append(end)
	return out


## Moving average over +-[radius] neighbours.
static func blur(values: PackedFloat32Array, radius: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(values.size())
	for i in values.size():
		var lo := maxi(i - radius, 0)
		var hi := mini(i + radius, values.size() - 1)
		var sum := 0.0
		for j in range(lo, hi + 1):
			sum += values[j]
		out[i] = sum / (hi - lo + 1)
	return out


static func tangent(poly: PackedVector2Array, i: int) -> Vector2:
	return (poly[mini(i + 1, poly.size() - 1)] - poly[maxi(i - 1, 0)]).normalized()


## Distance from [p] to the nearest sample of the polyline.
static func min_distance(poly: PackedVector2Array, p: Vector2) -> float:
	var best := INF
	for q in poly:
		best = minf(best, q.distance_squared_to(p))
	return sqrt(best)


static func bounds(poly: PackedVector2Array) -> Rect2:
	var rect := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		rect = rect.expand(p)
	return rect


static func _catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * (
		2.0 * p1
		+ (p2 - p0) * t
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
		+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3
	)
