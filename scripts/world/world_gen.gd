class_name WorldGen
extends RefCounted
## Детерминированная генерация карты: биомы, тип поверхности, декор и точки
## укрытий животных. Одинаковый seed => одинаковый мир (важно для сохранений).

enum Biome { FOREST, DESERT, LAKE, SNOW }
enum Terrain { GRASS, SAND, SNOW, WATER, SHORE }
enum Decor { NONE = -1, TREE, BUSH, CACTUS, ROCK, PINE, ICE, REEDS, FLOWERS }

const WIDTH: int = 128
const HEIGHT: int = 128
const TILE_SIZE: int = 32
const BORDER: int = 3
const START_CLEAR_RADIUS: int = 5

## Центры биомов в нормализованных координатах (порядок = enum Biome).
const BIOME_CENTERS: Array[Vector2] = [
	Vector2(0.22, 0.56), Vector2(0.80, 0.56), Vector2(0.50, 0.86), Vector2(0.50, 0.16),
]
const LAKE_CENTER: Vector2 = Vector2(0.50, 0.88)

var seed_value: int = 0
var biomes: PackedByteArray = PackedByteArray()
var terrain: PackedByteArray = PackedByteArray()
var decor: PackedInt32Array = PackedInt32Array()


func generate(p_seed: int) -> void:
	seed_value = p_seed
	var size: int = WIDTH * HEIGHT
	biomes.resize(size)
	terrain.resize(size)
	decor.resize(size)
	decor.fill(Decor.NONE)

	var warp: FastNoiseLite = FastNoiseLite.new()
	warp.seed = p_seed
	warp.frequency = 0.035
	var detail: FastNoiseLite = FastNoiseLite.new()
	detail.seed = p_seed + 17
	detail.frequency = 0.09

	for y: int in HEIGHT:
		for x: int in WIDTH:
			var i: int = index(x, y)
			var uv: Vector2 = Vector2((x + 0.5) / WIDTH, (y + 0.5) / HEIGHT)
			var w: Vector2 = Vector2(warp.get_noise_2d(x, y), warp.get_noise_2d(x + 731.0, y - 211.0)) * 0.10
			var p: Vector2 = uv + w
			var best: int = 0
			var best_d: float = INF
			for b: int in BIOME_CENTERS.size():
				var d: float = p.distance_squared_to(BIOME_CENTERS[b])
				if d < best_d:
					best_d = d
					best = b
			biomes[i] = best

			var t: int = Terrain.GRASS
			match best:
				Biome.DESERT:
					t = Terrain.SAND
				Biome.SNOW:
					t = Terrain.SNOW
				_:
					t = Terrain.GRASS

			var lake_d: float = ((uv - LAKE_CENTER) * Vector2(1.0, 1.7)).length()
			var lake_r: float = 0.13 + detail.get_noise_2d(x, y) * 0.035
			if lake_d < lake_r:
				t = Terrain.WATER
			elif lake_d < lake_r + 0.02:
				t = Terrain.SHORE

			var edge: int = mini(mini(x, y), mini(WIDTH - 1 - x, HEIGHT - 1 - y))
			if edge < BORDER:
				t = Terrain.WATER
			elif edge == BORDER:
				t = Terrain.SHORE
			terrain[i] = t

	_place_decor()


func _place_decor() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value + 99
	var center: Vector2i = start_cell()
	for y: int in HEIGHT:
		for x: int in WIDTH:
			var i: int = index(x, y)
			var r: float = rng.randf()
			if Vector2i(x, y).distance_to(center) < START_CLEAR_RADIUS:
				continue
			var t: int = terrain[i]
			if t == Terrain.WATER:
				continue
			if t == Terrain.SHORE:
				if r < 0.10:
					decor[i] = Decor.REEDS
				continue
			match biomes[i]:
				Biome.FOREST:
					if r < 0.10:
						decor[i] = Decor.TREE
					elif r < 0.14:
						decor[i] = Decor.BUSH
					elif r < 0.17:
						decor[i] = Decor.FLOWERS
				Biome.DESERT:
					if r < 0.025:
						decor[i] = Decor.CACTUS
					elif r < 0.045:
						decor[i] = Decor.ROCK
				Biome.SNOW:
					if r < 0.07:
						decor[i] = Decor.PINE
					elif r < 0.09:
						decor[i] = Decor.ICE
				Biome.LAKE:
					if r < 0.04:
						decor[i] = Decor.FLOWERS
					elif r < 0.06:
						decor[i] = Decor.TREE


## Расставляет укрытия: counts[biome] штук на биом, с минимальным расстоянием.
## Возвращает массив словарей {id, biome, cell, position}. Убирает декор под укрытием.
func generate_spots(counts: Array[int], min_spacing: int = 9) -> Array[Dictionary]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value + 2024
	var result: Array[Dictionary] = []
	var taken: Array[Vector2i] = []
	var start: Vector2i = start_cell()
	var n: int = 0
	for biome: int in counts.size():
		var placed: int = 0
		var attempts: int = 0
		while placed < counts[biome] and attempts < 6000:
			attempts += 1
			var c: Vector2i = Vector2i(rng.randi_range(BORDER + 2, WIDTH - BORDER - 3), rng.randi_range(BORDER + 2, HEIGHT - BORDER - 3))
			var i: int = index(c.x, c.y)
			if biomes[i] != biome or terrain[i] == Terrain.WATER or terrain[i] == Terrain.SHORE:
				continue
			if c.distance_to(start) < START_CLEAR_RADIUS + 4:
				continue
			if not _area_walkable(c, 2):
				continue
			# Озёрные звери живут у воды.
			if biome == Biome.LAKE and attempts < 5000 and not _water_within(c, 6):
				continue
			var spacing: float = float(min_spacing) if attempts < 4000 else float(min_spacing) * 0.6
			var ok: bool = true
			for other: Vector2i in taken:
				if c.distance_to(other) < spacing:
					ok = false
					break
			if not ok:
				continue
			taken.append(c)
			_clear_decor_around(c, 1)
			n += 1
			result.append({
				"id": "a%02d" % n,
				"biome": biome,
				"cell": c,
				"position": cell_center(c),
			})
			placed += 1
	return result


func _area_walkable(c: Vector2i, radius: int) -> bool:
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			if not is_walkable_cell(c + Vector2i(dx, dy)):
				return false
	return true


func _water_within(c: Vector2i, radius: int) -> bool:
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			var cc: Vector2i = c + Vector2i(dx, dy)
			if in_bounds(cc) and terrain[index(cc.x, cc.y)] == Terrain.WATER and cc.distance_to(Vector2i(WIDTH / 2, HEIGHT - 1)) < HEIGHT * 0.45:
				return true
	return false


func _clear_decor_around(c: Vector2i, radius: int) -> void:
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			var cc: Vector2i = c + Vector2i(dx, dy)
			if in_bounds(cc):
				decor[index(cc.x, cc.y)] = Decor.NONE


## Картинка мапи: 1 піксель = 1 тайл. Використовується міні-мапою та екраном мапи.
func build_map_image() -> Image:
	var img: Image = Image.create_empty(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	for y: int in HEIGHT:
		for x: int in WIDTH:
			var i: int = index(x, y)
			var col: Color
			match int(terrain[i]):
				Terrain.WATER:
					col = Color("3b7fc4")
				Terrain.SHORE:
					col = Color("c9b98c")
				Terrain.SAND:
					col = Color("dcbd78")
				Terrain.SNOW:
					col = Color("e6eef5")
				_:
					col = Color("4f8a3c") if biomes[i] == Biome.FOREST else Color("6aa84f")
			match decor[i]:
				Decor.TREE, Decor.PINE, Decor.BUSH:
					col = col.darkened(0.3)
				Decor.CACTUS, Decor.ROCK, Decor.ICE, Decor.REEDS:
					col = col.darkened(0.15)
				_:
					pass
			img.set_pixel(x, y, col)
	return img


func index(x: int, y: int) -> int:
	return y * WIDTH + x


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < WIDTH and c.y < HEIGHT


func is_walkable_cell(c: Vector2i) -> bool:
	return in_bounds(c) and terrain[index(c.x, c.y)] != Terrain.WATER


func is_walkable_pos(pos: Vector2) -> bool:
	return is_walkable_cell(cell_of(pos))


func cell_of(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / TILE_SIZE), floori(pos.y / TILE_SIZE))


func cell_center(c: Vector2i) -> Vector2:
	return Vector2((c.x + 0.5) * TILE_SIZE, (c.y + 0.5) * TILE_SIZE)


func biome_at(pos: Vector2) -> int:
	var c: Vector2i = cell_of(pos)
	if not in_bounds(c):
		return Biome.LAKE
	return biomes[index(c.x, c.y)]


func start_cell() -> Vector2i:
	return Vector2i(WIDTH / 2, HEIGHT / 2)


func start_position() -> Vector2:
	return cell_center(start_cell())


func world_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(WIDTH * TILE_SIZE, HEIGHT * TILE_SIZE))
