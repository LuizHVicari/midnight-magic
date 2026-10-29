class_name Terrain
extends Node3D
## Heightmap terrain. The map lives in plain arrays (one value per grid vertex) that Features
## edit freely; [finalize] then turns them into mesh chunks with trimesh collision plus one
## water mesh. Coordinates are meters, the map is centered on the origin, +z is south.

## The playable area is PLAY_HALF * 2 square; a 50 m ring of tall mountains around it walls it in.
const PLAY_HALF := 500.0
const SIZE := 1100.0
const HALF := SIZE * 0.5
const STEP := 2.0
const CELLS := 550
const N := CELLS + 1
const CHUNK_CELLS := 25
const NO_WATER := -1.0e9

## Bits of [keep_clear]: no trees / no small plants.
const CLEAR_TREES := 1
const CLEAR_ALL := 3

var heights := PackedFloat32Array()
## Terrain paint, 0..1 per vertex.
var dirt := PackedFloat32Array()
var cobble := PackedFloat32Array()
var wet := PackedFloat32Array()
## Water surface height per vertex, NO_WATER where there is none.
var water_y := PackedFloat32Array()
var flow := PackedVector2Array()
var keep_clear := PackedByteArray()


func _init() -> void:
	add_to_group("terrain")
	var count := N * N
	heights.resize(count)
	dirt.resize(count)
	cobble.resize(count)
	wet.resize(count)
	water_y.resize(count)
	water_y.fill(NO_WATER)
	flow.resize(count)
	keep_clear.resize(count)


## Rolling hills in the middle, rising into mountain ridges towards the edge of the playable
## area and into an unclimbable range just beyond it.
func generate_base(seed_value: int) -> void:
	var hills := _noise(seed_value, 0.0016, 4, FastNoiseLite.FRACTAL_FBM)
	var bumps := _noise(seed_value + 1, 0.012, 2, FastNoiseLite.FRACTAL_FBM)
	var rolls := _noise(seed_value + 3, 0.0055, 3, FastNoiseLite.FRACTAL_FBM)
	var ridges := _noise(seed_value + 2, 0.0035, 3, FastNoiseLite.FRACTAL_RIDGED)
	for iz in N:
		for ix in N:
			var x := ix * STEP - HALF
			var z := iz * STEP - HALF
			var edge := maxf(absf(x), absf(z)) / PLAY_HALF
			var rim := smoothstep(0.78, 1.0, edge)
			var range_wall := smoothstep(1.0, 1.09, edge)
			var h := 12.0 + hills.get_noise_2d(x, z) * 34.0 + rolls.get_noise_2d(x, z) * 11.0
			h += bumps.get_noise_2d(x, z) * 2.5
			h += rim * (45.0 + ridges.get_noise_2d(x, z) * 30.0)
			h += range_wall * (110.0 + ridges.get_noise_2d(x, z) * 40.0)
			heights[iz * N + ix] = h


func _noise(seed_value: int, frequency: float, octaves: int, fractal: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_type = fractal
	noise.fractal_octaves = octaves
	return noise


# --- queries ------------------------------------------------------------------

func index_at(x: float, z: float) -> int:
	var ix := clampi(roundi((x + HALF) / STEP), 0, CELLS)
	var iz := clampi(roundi((z + HALF) / STEP), 0, CELLS)
	return iz * N + ix


func height_at(x: float, z: float) -> float:
	var fx := clampf((x + HALF) / STEP, 0.0, CELLS - 0.001)
	var fz := clampf((z + HALF) / STEP, 0.0, CELLS - 0.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var i := iz * N + ix
	var top := lerpf(heights[i], heights[i + 1], tx)
	var bottom := lerpf(heights[i + N], heights[i + N + 1], tx)
	return lerpf(top, bottom, tz)


func normal_at(x: float, z: float) -> Vector3:
	var e := 1.5
	return Vector3(
		height_at(x - e, z) - height_at(x + e, z),
		2.0 * e,
		height_at(x, z - e) - height_at(x, z + e),
	).normalized()


## Lowest ground height at the center and eight points around it on a circle of [radius].
func lowest_around(x: float, z: float, radius: float) -> float:
	var low := height_at(x, z)
	for k in 8:
		var offset := Vector2.from_angle(k * TAU / 8.0) * radius
		low = minf(low, height_at(x + offset.x, z + offset.y))
	return low


func is_water(x: float, z: float) -> bool:
	var i := index_at(x, z)
	return water_y[i] > NO_WATER * 0.5 and water_y[i] > heights[i]


## Height of the water surface at a point; only meaningful where [method is_water] is true.
func water_level_at(x: float, z: float) -> float:
	return water_y[index_at(x, z)]


func in_bounds(x: float, z: float, margin := 0.0) -> bool:
	return absf(x) < HALF - margin and absf(z) < HALF - margin


# --- editing helpers for features ---------------------------------------------

## Calls [visit](index, x, z, distance) for every grid vertex inside the disc.
func for_cells_in_disc(center: Vector2, radius: float, visit: Callable) -> void:
	var ix0 := maxi(floori((center.x - radius + HALF) / STEP), 0)
	var ix1 := mini(ceili((center.x + radius + HALF) / STEP), CELLS)
	var iz0 := maxi(floori((center.y - radius + HALF) / STEP), 0)
	var iz1 := mini(ceili((center.y + radius + HALF) / STEP), CELLS)
	for iz in range(iz0, iz1 + 1):
		for ix in range(ix0, ix1 + 1):
			var x := ix * STEP - HALF
			var z := iz * STEP - HALF
			var d := center.distance_to(Vector2(x, z))
			if d <= radius:
				visit.call(iz * N + ix, x, z, d)


## Calls [visit](index, distance, along) once per grid vertex within [radius] of the polyline,
## using its nearest point. [along] is the fractional sample index of that point.
func for_cells_near(poly: PackedVector2Array, radius: float, visit: Callable) -> void:
	var best := {}
	for s in poly.size() - 1:
		var a := poly[s]
		var ab := poly[s + 1] - a
		var len_sq := maxf(ab.length_squared(), 0.0001)
		var lo := Vector2(minf(a.x, a.x + ab.x), minf(a.y, a.y + ab.y)) - Vector2(radius, radius)
		var hi := Vector2(maxf(a.x, a.x + ab.x), maxf(a.y, a.y + ab.y)) + Vector2(radius, radius)
		var ix0 := maxi(floori((lo.x + HALF) / STEP), 0)
		var ix1 := mini(ceili((hi.x + HALF) / STEP), CELLS)
		var iz0 := maxi(floori((lo.y + HALF) / STEP), 0)
		var iz1 := mini(ceili((hi.y + HALF) / STEP), CELLS)
		for iz in range(iz0, iz1 + 1):
			for ix in range(ix0, ix1 + 1):
				var p := Vector2(ix * STEP - HALF, iz * STEP - HALF)
				var t := clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
				var d := p.distance_to(a + ab * t)
				var idx := iz * N + ix
				if d <= radius and (not best.has(idx) or d < best[idx].x):
					best[idx] = Vector2(d, s + t)
	for idx in best:
		visit.call(idx, best[idx].x, best[idx].y)


# --- meshes -------------------------------------------------------------------

## Call once every feature has shaped the grids.
func finalize() -> void:
	for i in N * N:
		wet[i] = _wetness(i)
	var material := _terrain_material()
	for cz in CELLS / CHUNK_CELLS:
		for cx in CELLS / CHUNK_CELLS:
			_build_chunk(cx, cz, material)
	_build_water()


func _wetness(i: int) -> float:
	if water_y[i] < NO_WATER * 0.5:
		return 0.0
	return clampf(1.0 - (heights[i] - water_y[i]) / 1.6, 0.0, 1.0)


func _terrain_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/shaders/terrain.gdshader")
	material.set_shader_parameter("patches", load("res://assets/textures/patterns/pattern37.png"))
	material.set_shader_parameter("tufts", load("res://assets/textures/patterns/pattern56.png"))
	return material


func _build_chunk(cx: int, cz: int, material: Material) -> void:
	var n := CHUNK_CELLS + 1
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	verts.resize(n * n)
	normals.resize(n * n)
	colors.resize(n * n)
	var ix0 := cx * CHUNK_CELLS
	var iz0 := cz * CHUNK_CELLS
	for j in n:
		for i in n:
			var idx := (iz0 + j) * N + ix0 + i
			verts[j * n + i] = Vector3(i * STEP, heights[idx], j * STEP)
			normals[j * n + i] = _grid_normal(ix0 + i, iz0 + j)
			colors[j * n + i] = Color(dirt[idx], cobble[idx], wet[idx], 1.0)

	var indices := PackedInt32Array()
	var faces := PackedVector3Array()
	for j in CHUNK_CELLS:
		for i in CHUNK_CELLS:
			var a := j * n + i
			var b := a + 1
			var c := a + n
			var d := c + 1
			indices.append_array([a, b, c, b, d, c])
			faces.append_array([verts[a], verts[b], verts[c], verts[b], verts[d], verts[c]])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = Vector3(ix0 * STEP - HALF, 0.0, iz0 * STEP - HALF)
	add_child(instance)

	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	var body := StaticBody3D.new()
	body.add_child(collider)
	instance.add_child(body)


func _grid_normal(ix: int, iz: int) -> Vector3:
	var hl := heights[iz * N + maxi(ix - 1, 0)]
	var hr := heights[iz * N + mini(ix + 1, CELLS)]
	var hu := heights[maxi(iz - 1, 0) * N + ix]
	var hd := heights[mini(iz + 1, CELLS) * N + ix]
	return Vector3(hl - hr, 2.0 * STEP, hu - hd).normalized()


## One flat-shaded mesh for every lake and river: all grid quads touching a vertex that
## sits below its water surface. Vertex color carries flow direction (rg) and depth (a).
func _build_water() -> void:
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for iz in CELLS:
		for ix in CELLS:
			var corners := [iz * N + ix, iz * N + ix + 1, (iz + 1) * N + ix, (iz + 1) * N + ix + 1]
			if not _quad_has_water(corners):
				continue
			var base := verts.size()
			var level := _quad_level(corners)
			for k in 4:
				var idx: int = corners[k]
				var x := (ix + (k % 2)) * STEP - HALF
				var z := (iz + (k / 2)) * STEP - HALF
				verts.append(Vector3(x, level, z))
				var f := flow[idx]
				var depth := clampf((water_y[idx] - heights[idx]) / 3.0, 0.0, 1.0)
				colors.append(Color(f.x * 0.5 + 0.5, f.y * 0.5 + 0.5, 0.0, depth))
			indices.append_array([base, base + 1, base + 2, base + 1, base + 3, base + 2])
	if verts.is_empty():
		return

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var water := MeshInstance3D.new()
	water.name = "Water"
	water.mesh = mesh
	water.material_override = _water_material()
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


func _quad_has_water(corners: Array) -> bool:
	for idx: int in corners:
		if water_y[idx] > NO_WATER * 0.5 and water_y[idx] > heights[idx]:
			return true
	return false


## Water is flat across a quad; take the mean of the corners that have a surface.
func _quad_level(corners: Array) -> float:
	var sum := 0.0
	var count := 0
	for idx: int in corners:
		if water_y[idx] > NO_WATER * 0.5:
			sum += water_y[idx]
			count += 1
	return sum / count


func _water_material() -> ShaderMaterial:
	var ripples := FastNoiseLite.new()
	ripples.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ripples.frequency = 0.03
	ripples.fractal_octaves = 3
	var image := ripples.get_seamless_image(256, 256)
	image.bump_map_to_normal_map(6.0)
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/shaders/water.gdshader")
	material.set_shader_parameter("normal_map", ImageTexture.create_from_image(image))
	return material
