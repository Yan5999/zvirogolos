class_name TileSetBuilder
extends RefCounted
## Строит TileSet целиком в коде: атлас рисуется в Image (плейсхолдер-арт).
## Чтобы заменить на нормальный арт — подставьте свою текстуру атласа с той же
## раскладкой (8x2 тайлов по 32 px) в build() или сделайте .tres TileSet в редакторе.

const TILE: int = 32
const COLUMNS: int = 8
const SOURCE_ID: int = 0

## Варианты тайлов поверхности (ряд 0) по WorldGen.Terrain.
const TERRAIN_TILES: Dictionary = {
	WorldGen.Terrain.GRASS: [Vector2i(0, 0), Vector2i(1, 0)],
	WorldGen.Terrain.SAND: [Vector2i(2, 0), Vector2i(3, 0)],
	WorldGen.Terrain.SNOW: [Vector2i(4, 0), Vector2i(5, 0)],
	WorldGen.Terrain.WATER: [Vector2i(6, 0)],
	WorldGen.Terrain.SHORE: [Vector2i(7, 0)],
}


static func decor_tile(decor: int) -> Vector2i:
	return Vector2i(decor, 1)


static func build() -> TileSet:
	var img: Image = _draw_atlas()
	var ts: TileSet = TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)

	var src: TileSetAtlasSource = TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(src, SOURCE_ID)
	for y: int in 2:
		for x: int in COLUMNS:
			src.create_tile(Vector2i(x, y))

	var water: TileData = src.get_tile_data(Vector2i(6, 0), 0)
	var h: float = TILE * 0.5
	water.add_collision_polygon(0)
	water.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)]))
	return ts


static func _draw_atlas() -> Image:
	var img: Image = Image.create_empty(TILE * COLUMNS, TILE * 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	# --- поверхность ---
	_ground(img, 0, Color("5f9e4a"), 0.06, rng)
	_ground(img, 1, Color("5a9846"), 0.08, rng)
	_ground(img, 2, Color("e2c37f"), 0.05, rng)
	_ground(img, 3, Color("dbb974"), 0.07, rng)
	_ground(img, 4, Color("e8f1f7"), 0.03, rng)
	_ground(img, 5, Color("e3edf5"), 0.035, rng)
	_ground(img, 6, Color("3b7fc4"), 0.04, rng)
	for k: int in 3:
		var wy: int = 6 + k * 10
		img.fill_rect(Rect2i(6 * TILE + 4 + k * 6, wy, 9, 1), Color("7fb6e8"))
	_ground(img, 7, Color("c9b98c"), 0.06, rng)
	# --- декор ---
	var o: Vector2i
	o = Vector2i(0, TILE)  # дерево
	_disc(img, o + Vector2i(16, 18), 12, Color("2f6b2c"))
	_disc(img, o + Vector2i(13, 14), 8, Color("3f8a39"))
	_disc(img, o + Vector2i(19, 12), 5, Color("4fa046"))
	o = Vector2i(TILE, TILE)  # куст
	_disc(img, o + Vector2i(11, 19), 7, Color("357a31"))
	_disc(img, o + Vector2i(20, 18), 8, Color("3c8737"))
	_disc(img, o + Vector2i(16, 14), 6, Color("4a9c43"))
	o = Vector2i(TILE * 2, TILE)  # кактус
	img.fill_rect(Rect2i(o.x + 13, o.y + 6, 6, 22), Color("3f8f4f"))
	img.fill_rect(Rect2i(o.x + 6, o.y + 12, 4, 8), Color("3f8f4f"))
	img.fill_rect(Rect2i(o.x + 6, o.y + 18, 8, 3), Color("3f8f4f"))
	img.fill_rect(Rect2i(o.x + 22, o.y + 10, 4, 7), Color("3f8f4f"))
	img.fill_rect(Rect2i(o.x + 18, o.y + 15, 8, 3), Color("3f8f4f"))
	o = Vector2i(TILE * 3, TILE)  # камень
	_disc(img, o + Vector2i(16, 19), 9, Color("8a8072"))
	_disc(img, o + Vector2i(13, 16), 5, Color("a39a8b"))
	o = Vector2i(TILE * 4, TILE)  # ель
	for k: int in 4:
		var w: int = 22 - k * 5
		img.fill_rect(Rect2i(o.x + 16 - w / 2, o.y + 24 - k * 6, w, 6), Color("2c5e4a").lightened(k * 0.06))
	img.fill_rect(Rect2i(o.x + 14, o.y + 26, 4, 4), Color("6b4a2f"))
	o = Vector2i(TILE * 5, TILE)  # лёд
	_disc(img, o + Vector2i(16, 18), 7, Color("a8d8f0"))
	img.fill_rect(Rect2i(o.x + 14, o.y + 8, 4, 14), Color("c8ecff"))
	o = Vector2i(TILE * 6, TILE)  # камыш
	for k: int in 5:
		var rx: int = o.x + 7 + k * 4
		img.fill_rect(Rect2i(rx, o.y + 10 + (k % 2) * 4, 2, 18 - (k % 2) * 4), Color("5d7f3a"))
		img.fill_rect(Rect2i(rx, o.y + 8 + (k % 2) * 4, 2, 4), Color("7a5534"))
	o = Vector2i(TILE * 7, TILE)  # цветы
	var petals: Array[Color] = [Color("f2d14b"), Color("ef7fa7"), Color("ffffff"), Color("b38cf0")]
	for k: int in 6:
		var p: Vector2i = o + Vector2i(rng.randi_range(5, 26), rng.randi_range(5, 26))
		_disc(img, p, 2, petals[k % petals.size()])
	return img


static func _ground(img: Image, col: int, base: Color, variance: float, rng: RandomNumberGenerator) -> void:
	var ox: int = col * TILE
	for y: int in range(0, TILE, 2):
		for x: int in range(0, TILE, 2):
			var c: Color = base.lightened(rng.randf_range(0.0, variance)) if rng.randf() < 0.5 else base.darkened(rng.randf_range(0.0, variance))
			img.fill_rect(Rect2i(ox + x, y, 2, 2), c)


static func _disc(img: Image, center: Vector2i, r: int, color: Color) -> void:
	for y: int in range(-r, r + 1):
		for x: int in range(-r, r + 1):
			if x * x + y * y <= r * r:
				var p: Vector2i = center + Vector2i(x, y)
				if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height():
					img.set_pixelv(p, color)
