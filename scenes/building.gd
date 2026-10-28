class_name Building
## Assembles a closed house from modular Fantasy Town pieces. Every row of cells gets
## its own gable with the ridge along x, so deep houses end up with a twin-gable roof.

enum Roof { GABLE, HIGH }

const EDGE_YAW := {"E": 0.0, "N": 90.0, "W": 180.0, "S": -90.0}
const WINDOWS := ["window-small", "window-shutters", "window-glass"]


## [nw] is the center of the north-west cell at ground level.
static func build(
	parent: Node3D,
	nw: Vector3,
	w: int,
	d: int,
	door_side: String,
	floors := 1,
	wood := false,
	roof := Roof.GABLE,
) -> void:
	var prefix := "wall-wood" if wood else "wall"
	var door_i := w / 2 if door_side in ["N", "S"] else (w - 1 if door_side == "E" else 0)
	var door_j := d / 2 if door_side in ["E", "W"] else (d - 1 if door_side == "S" else 0)

	for f in floors:
		for j in d:
			for i in w:
				var pos := nw + Vector3(i * Kit.CELL, f * Kit.CELL, j * Kit.CELL)
				for edge in _edges(i, j, w, d):
					var model := prefix
					if edge == door_side and i == door_i and j == door_j:
						model = prefix + ("-door" if f == 0 else "-" + WINDOWS[0])
					elif (i + j + f) % 2 == 0:
						model = prefix + "-" + WINDOWS[(i + j + f) % WINDOWS.size()]
					Kit.place(parent, "town", model, pos, EDGE_YAW[edge], Kit.Collision.NONE)

	_roof(parent, nw, w, d, floors, roof)

	# Solid footprint so the player cannot walk through doors or walls.
	var size := Vector3(w * Kit.CELL, floors * Kit.CELL, d * Kit.CELL)
	var center := nw + Vector3((w - 1) * 0.5 * Kit.CELL, size.y * 0.5, (d - 1) * 0.5 * Kit.CELL)
	Kit.add_block(parent, center, size)


static func _edges(i: int, j: int, w: int, d: int) -> Array[String]:
	var edges: Array[String] = []
	if i == 0:
		edges.append("W")
	if i == w - 1:
		edges.append("E")
	if j == 0:
		edges.append("N")
	if j == d - 1:
		edges.append("S")
	return edges


static func _roof(parent: Node3D, nw: Vector3, w: int, d: int, floors: int, roof: Roof) -> void:
	var model := "roof-gable" if roof == Roof.GABLE else "roof-high-gable"
	var y := floors * Kit.CELL
	for j in d:
		for i in w:
			Kit.place(parent, "town", model, nw + Vector3(i * Kit.CELL, y, j * Kit.CELL), 0.0, Kit.Collision.NONE)
