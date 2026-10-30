class_name HeroOutfit
extends RefCounted
## Recolors the mage's cloth to match the equipped element. The model's texture is a palette:
## a grid of small gradient swatches, one per color. Here the robe and cape swatches are repainted
## per element (keeping their light-to-dark shading) and the textures are swapped on the model.

const TEXTURE := "res://assets/models/kaykit/Mage_mage_texture.png"
const COLUMNS := 8
const ROWS := 4
## Blues and purples are the robe, hat and sleeves; magentas are the cape. Anything else (skin,
## hair, boots, the orange hat band) keeps its color.
const CLOTH_HUES := Vector2(0.55, 0.8)
const CAPE_HUES := Vector2(0.8, 0.97)
const MIN_SATURATION := 0.3

var _materials: Array[BaseMaterial3D] = []
var _source: Image
var _textures := {}  # Element -> ImageTexture


## Gives every mesh of [param model] its own material, so recoloring it touches nothing else.
func setup(model: Node3D) -> void:
	_source = (load(TEXTURE) as Texture2D).get_image()
	if _source.is_compressed():
		_source.decompress()
	_source.convert(Image.FORMAT_RGBA8)
	for mesh_node: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh_node.mesh.get_surface_count():
			var original := mesh_node.get_active_material(surface) as BaseMaterial3D
			if original == null:
				continue
			var copy := original.duplicate() as BaseMaterial3D
			mesh_node.set_surface_override_material(surface, copy)
			_materials.append(copy)


func dress(element: Element) -> void:
	if not _textures.has(element):
		_textures[element] = ImageTexture.create_from_image(_painted(element))
	for material in _materials:
		material.albedo_texture = _textures[element]


func _painted(element: Element) -> Image:
	var image := _source.duplicate() as Image
	var size := Vector2i(image.get_width() / COLUMNS, image.get_height() / ROWS)
	for row in ROWS:
		for column in COLUMNS:
			var cell := Vector2i(column, row)
			var tint := _tint_for(_average(image, cell, size), element)
			if tint.a > 0.0:
				_repaint(image, cell, size, tint)
	return image


## The color a swatch should become, or a fully transparent color to leave it alone.
func _tint_for(average: Color, element: Element) -> Color:
	if average.s < MIN_SATURATION:
		return Color(0, 0, 0, 0)
	if average.h >= CLOTH_HUES.x and average.h < CLOTH_HUES.y:
		return element.robe
	if average.h >= CAPE_HUES.x and average.h < CAPE_HUES.y:
		return element.cape
	return Color(0, 0, 0, 0)


func _average(image: Image, cell: Vector2i, size: Vector2i) -> Color:
	var sum := Vector3.ZERO
	var origin := cell * size
	for y in size.y:
		for x in size.x:
			var pixel := image.get_pixelv(origin + Vector2i(x, y))
			sum += Vector3(pixel.r, pixel.g, pixel.b)
	sum /= size.x * size.y
	return Color(sum.x, sum.y, sum.z)


## Paints a swatch in [param tint], with its original gradient deciding how light or dark.
func _repaint(image: Image, cell: Vector2i, size: Vector2i, tint: Color) -> void:
	var origin := cell * size
	var average := 0.0
	for y in size.y:
		for x in size.x:
			average += _luma(image.get_pixelv(origin + Vector2i(x, y)))
	average /= size.x * size.y
	for y in size.y:
		for x in size.x:
			var at := origin + Vector2i(x, y)
			var shade := _luma(image.get_pixelv(at)) / maxf(average, 0.001)
			image.set_pixelv(at, Color(tint.r * shade, tint.g * shade, tint.b * shade, 1.0))


func _luma(color: Color) -> float:
	return color.r * 0.299 + color.g * 0.587 + color.b * 0.114
