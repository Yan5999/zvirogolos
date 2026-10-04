extends SceneTree
## Генератор .tres для 30 реальних видів (по одному на кожну схованку).
## Після генерації .tres можна правити в інспекторі.
## Запуск: godot --headless --path . -s res://tools/gen_species.gd

const H: Dictionary = {"bush": 0, "rock": 1, "burrow": 2, "snow": 3, "reeds": 4}
const E: Dictionary = {"none": 0, "pointy": 1, "round": 2, "long": 3}
const F: Dictionary = {"none": 0, "horn": 1, "beak": 2, "cap": 3, "spikes": 4, "antlers": 5, "hump": 6, "shell": 7, "tusks": 8}
const T: Dictionary = {"none": 0, "short": 1, "bushy": 2, "thin": 3, "flat": 4}

## Біоми: 0 ліс (8), 1 пустеля (7), 2 озеро (7), 3 сніги (8).
## Поля, яких немає у рядку, мають значення за замовчуванням із SpeciesData.
const DATA: Array[Dictionary] = [
	# --- Ліс ---
	{"id": "red_fox", "name": "Лисиця звичайна", "latin": "Vulpes vulpes", "desc": "Руда хитрунка з пишним хвостом. Чує мишу навіть під снігом.", "biome": 0, "hide": "bush", "body": "d8692a", "belly": "f6e6d2", "accent": "3a2a20", "r": Vector2(13, 8), "ears": "pointy", "tail": "bushy", "pitch": 1.1},
	{"id": "hedgehog", "name": "Їжак звичайний", "latin": "Erinaceus europaeus", "desc": "Вночі полює на равликів і жуків, а від небезпеки згортається в колючу кулю.", "biome": 0, "hide": "burrow", "body": "8a7258", "belly": "d9c4a5", "accent": "5a4630", "r": Vector2(11, 8), "ears": "round", "ear_scale": 0.6, "feature": "spikes", "head": 0.85, "pitch": 1.35},
	{"id": "red_squirrel", "name": "Білка звичайна", "latin": "Sciurus vulgaris", "desc": "Ховає жолуді й горіхи на зиму — і часто про них забуває, садячи нові дерева.", "biome": 0, "hide": "bush", "body": "c0642c", "belly": "f4e2c8", "accent": "8a3f18", "r": Vector2(8, 7), "ears": "pointy", "tufts": true, "tail": "bushy", "pitch": 1.4},
	{"id": "brown_bear", "name": "Ведмідь бурий", "latin": "Ursus arctos", "desc": "Найбільший хижак наших лісів. Узимку спить у барлозі.", "biome": 0, "hide": "rock", "body": "6b4a2e", "belly": "8a6a48", "accent": "3a2818", "r": Vector2(20, 14), "ears": "round", "ear_scale": 0.7, "tail": "short", "pitch": 0.7, "speed": 20.0},
	{"id": "red_deer", "name": "Олень благородний", "latin": "Cervus elaphus", "desc": "Восени самці гучно трублять, а роги скидають і відрощують щороку.", "biome": 0, "hide": "bush", "body": "a8703c", "belly": "e8d0a8", "accent": "e8dcc0", "r": Vector2(15, 10), "ears": "pointy", "feature": "antlers", "tail": "short", "neck": 1.0, "head": 0.85, "pitch": 0.85},
	{"id": "badger", "name": "Борсук", "latin": "Meles meles", "desc": "Риє глибокі нори з багатьма виходами, де живуть цілі покоління.", "biome": 0, "hide": "burrow", "body": "8c8c8c", "belly": "4a4a4a", "accent": "f4f4f4", "head_color": "f2f2f2", "r": Vector2(14, 8), "ears": "round", "ear_scale": 0.6, "mask": true, "tail": "short", "pitch": 0.95},
	{"id": "tawny_owl", "name": "Сова сіра", "latin": "Strix aluco", "desc": "Літає зовсім беззвучно і може повернути голову майже назад.", "biome": 0, "hide": "bush", "body": "8a6e52", "belly": "d8c4a4", "accent": "e0a030", "r": Vector2(9, 10), "ears": "none", "feature": "beak", "tail": "short", "head": 1.3, "pitch": 1.0},
	{"id": "brown_hare", "name": "Заєць сірий", "latin": "Lepus europaeus", "desc": "Розганяється до 70 км/год і різко петляє, тікаючи від лисиці.", "biome": 0, "hide": "bush", "body": "b08a5e", "belly": "ecdcc0", "accent": "3a2a1a", "r": Vector2(11, 8), "ears": "long", "tail": "short", "pitch": 1.25},
	# --- Пустеля ---
	{"id": "dromedary", "name": "Верблюд одногорбий", "latin": "Camelus dromedarius", "desc": "Тижнями обходиться без води, а в горбі запасає жир.", "biome": 1, "hide": "rock", "body": "c89a5e", "belly": "e2c08a", "accent": "8a6a3a", "r": Vector2(18, 11), "ears": "pointy", "ear_scale": 0.5, "feature": "hump", "tail": "thin", "neck": 1.6, "head": 0.8, "pitch": 0.75, "speed": 18.0},
	{"id": "fennec", "name": "Фенек", "latin": "Vulpes zerda", "desc": "Найменша лисиця у світі. Величезні вуха охолоджують тіло в спеку.", "biome": 1, "hide": "burrow", "body": "e8c890", "belly": "fff2dc", "accent": "b08a5a", "r": Vector2(9, 7), "ears": "pointy", "ear_scale": 1.9, "tail": "bushy", "pitch": 1.35},
	{"id": "meerkat", "name": "Сурикат", "latin": "Suricata suricatta", "desc": "Стоїть стовпчиком і пильнує, поки родина шукає їжу.", "biome": 1, "hide": "burrow", "body": "c8a878", "belly": "e8d8b8", "accent": "4a3a2a", "r": Vector2(7, 11), "ears": "round", "ear_scale": 0.5, "mask": true, "tail": "thin", "neck": 0.5, "pitch": 1.3},
	{"id": "jerboa", "name": "Тушканчик великий", "latin": "Allactaga major", "desc": "Стрибає на довгих задніх лапах, наче маленький кенгуру.", "biome": 1, "hide": "burrow", "body": "d4b080", "belly": "f6ead4", "accent": "2a2a2a", "r": Vector2(7, 7), "ears": "long", "tail": "thin", "head": 1.1, "pitch": 1.5},
	{"id": "steppe_tortoise", "name": "Черепаха степова", "latin": "Testudo horsfieldii", "desc": "Повільна, але живе понад 40 років. Від спеки ховається в нору.", "biome": 1, "hide": "rock", "body": "9a9a62", "belly": "c8c08a", "accent": "7a6438", "r": Vector2(14, 8), "ears": "none", "feature": "shell", "tail": "short", "head": 0.7, "pitch": 0.8, "speed": 9.0},
	{"id": "desert_monitor", "name": "Варан сірий", "latin": "Varanus griseus", "desc": "Найбільша ящірка пустель Середньої Азії. Бігає швидше за людину.", "biome": 1, "hide": "rock", "body": "8a8a6a", "belly": "b8b090", "accent": "5a5a3a", "r": Vector2(16, 6), "ears": "none", "tail": "thin", "head": 0.9, "pitch": 0.9},
	{"id": "griffon_vulture", "name": "Сип білоголовий", "latin": "Gyps fulvus", "desc": "Годинами ширяє в небі, видивляючись здобич з висоти.", "biome": 1, "hide": "rock", "body": "9a7450", "belly": "c8a882", "accent": "e8d0a0", "head_color": "f0ece4", "r": Vector2(12, 11), "ears": "none", "feature": "beak", "tail": "short", "neck": 0.6, "head": 0.9, "pitch": 0.85},
	# --- Озеро ---
	{"id": "mallard", "name": "Крижень", "latin": "Anas platyrhynchos", "desc": "Найпоширеніша дика качка. Селезень має смарагдово-зелену голову.", "biome": 2, "hide": "reeds", "body": "8a7a62", "belly": "d8ccb8", "accent": "f0b030", "head_color": "2e6a3a", "r": Vector2(11, 8), "ears": "none", "feature": "beak", "tail": "short", "neck": 0.4, "pitch": 1.1},
	{"id": "common_frog", "name": "Жаба трав'яна", "latin": "Rana temporaria", "desc": "Навесні збирається у ставках і кумкає гучним хором.", "biome": 2, "hide": "reeds", "body": "6a8a3a", "belly": "d8d8a0", "accent": "3a4a1a", "r": Vector2(10, 7), "ears": "none", "head": 1.1, "pitch": 0.9, "wanders": false},
	{"id": "beaver", "name": "Бобер європейський", "latin": "Castor fiber", "desc": "Будує греблі з гілок і може гризти дерево цілу ніч.", "biome": 2, "hide": "burrow", "body": "7a5232", "belly": "a8805a", "accent": "3a3a3a", "r": Vector2(15, 10), "ears": "round", "ear_scale": 0.5, "tail": "flat", "pitch": 0.85},
	{"id": "otter", "name": "Видра річкова", "latin": "Lutra lutra", "desc": "Чудово плаває та пірнає, а граючись, катається з берега.", "biome": 2, "hide": "bush", "body": "6a4a32", "belly": "c8a888", "accent": "3a2818", "r": Vector2(16, 7), "ears": "round", "ear_scale": 0.5, "tail": "thin", "pitch": 1.1},
	{"id": "grey_heron", "name": "Чапля сіра", "latin": "Ardea cinerea", "desc": "Годинами нерухомо стоїть у воді, чатуючи на рибу.", "biome": 2, "hide": "reeds", "body": "9aa4ac", "belly": "e8ecf0", "accent": "e0b040", "head_color": "e8ecf0", "r": Vector2(9, 9), "ears": "none", "feature": "beak", "tail": "short", "neck": 2.0, "head": 0.8, "pitch": 0.95},
	{"id": "mute_swan", "name": "Лебідь-шипун", "latin": "Cygnus olor", "desc": "Коли сердиться — шипить. Пари лебедів часто разом усе життя.", "biome": 2, "hide": "reeds", "body": "f4f4f4", "belly": "ffffff", "accent": "e86a2a", "r": Vector2(14, 9), "ears": "none", "feature": "beak", "tail": "short", "neck": 1.8, "head": 0.8, "pitch": 0.9},
	{"id": "white_stork", "name": "Лелека білий", "latin": "Ciconia ciconia", "desc": "Символ дому та весни. Щороку повертається до свого гнізда.", "biome": 2, "hide": "reeds", "body": "f4f4f4", "belly": "2a2a2a", "accent": "e03a2a", "r": Vector2(10, 10), "ears": "none", "feature": "beak", "tail": "short", "neck": 1.2, "head": 0.85, "pitch": 1.0},
	# --- Сніги ---
	{"id": "polar_bear", "name": "Ведмідь білий", "latin": "Ursus maritimus", "desc": "Найбільший наземний хижак. Полює на тюленів на кризі.", "biome": 3, "hide": "snow", "body": "f2efe4", "belly": "ffffff", "accent": "2a2a2a", "r": Vector2(21, 14), "ears": "round", "ear_scale": 0.6, "tail": "short", "pitch": 0.7, "speed": 20.0},
	{"id": "emperor_penguin", "name": "Пінгвін імператорський", "latin": "Aptenodytes forsteri", "desc": "Найбільший пінгвін. Тато всю зиму гріє яйце на своїх лапах.", "biome": 3, "hide": "snow", "body": "2a2e3a", "belly": "f4f4f4", "accent": "f0a030", "r": Vector2(9, 13), "ears": "none", "feature": "beak", "head": 0.9, "pitch": 1.0},
	{"id": "arctic_fox", "name": "Песець", "latin": "Vulpes lagopus", "desc": "Узимку білий, улітку бурий. Витримує мороз до −50 °C.", "biome": 3, "hide": "snow", "body": "f4f6f8", "belly": "ffffff", "accent": "3a3a3a", "r": Vector2(12, 8), "ears": "pointy", "ear_scale": 0.8, "tail": "bushy", "pitch": 1.2},
	{"id": "reindeer", "name": "Північний олень", "latin": "Rangifer tarandus", "desc": "Роги мають і самці, і самки. Мігрує на тисячі кілометрів.", "biome": 3, "hide": "rock", "body": "8a7a6a", "belly": "e8e0d4", "accent": "d8c8a8", "r": Vector2(15, 11), "ears": "pointy", "feature": "antlers", "tail": "short", "neck": 0.9, "head": 0.85, "pitch": 0.85},
	{"id": "walrus", "name": "Морж", "latin": "Odobenus rosmarus", "desc": "Бивнями чіпляється за кригу, щоб вибратися з води.", "biome": 3, "hide": "rock", "body": "a87a5a", "belly": "c89a7a", "accent": "fff8e8", "r": Vector2(20, 12), "ears": "none", "feature": "tusks", "head": 0.9, "pitch": 0.65, "speed": 10.0},
	{"id": "ringed_seal", "name": "Нерпа", "latin": "Pusa hispida", "desc": "Дихає через лунки в льоду, які сама ж і продряпує.", "biome": 3, "hide": "snow", "body": "7a8490", "belly": "b8c0c8", "accent": "3a4048", "r": Vector2(17, 8), "ears": "none", "tail": "flat", "pitch": 1.0, "speed": 10.0},
	{"id": "snowy_owl", "name": "Сова біла", "latin": "Bubo scandiacus", "desc": "На відміну від більшості сов полює вдень серед тундри.", "biome": 3, "hide": "snow", "body": "f4f4f0", "belly": "ffffff", "accent": "f0c030", "r": Vector2(10, 11), "ears": "none", "feature": "beak", "tail": "short", "head": 1.3, "pitch": 1.05},
	{"id": "lynx", "name": "Рись", "latin": "Lynx lynx", "desc": "Китиці на вухах і широкі лапи, що не провалюються в сніг.", "biome": 3, "hide": "rock", "body": "c8a07a", "belly": "f0e0c8", "accent": "2a2a2a", "r": Vector2(14, 10), "ears": "pointy", "tufts": true, "tail": "short", "pitch": 0.95},
]


func _init() -> void:
	var dir: DirAccess = DirAccess.open("res://resources/species/")
	for f: String in dir.get_files():
		if f.ends_with(".tres"):
			dir.remove(f)
	var db: SpeciesDatabase = SpeciesDatabase.new()
	for row: Dictionary in DATA:
		var s: SpeciesData = SpeciesData.new()
		s.id = StringName(row["id"])
		s.display_name = row["name"]
		s.latin_name = row["latin"]
		s.description = row["desc"]
		s.biome = row["biome"]
		s.hideout = H[row["hide"]]
		s.body_color = Color(row["body"])
		s.belly_color = Color(row["belly"])
		s.accent_color = Color(row["accent"])
		if row.has("head_color"):
			s.head_color = Color(row["head_color"])
		s.body_radii = row["r"]
		s.ears = E[row.get("ears", "round")]
		s.ear_scale = row.get("ear_scale", 1.0)
		s.ear_tufts = row.get("tufts", false)
		s.face_mask = row.get("mask", false)
		s.feature = F[row.get("feature", "none")]
		s.tail = T[row.get("tail", "none")]
		s.neck_length = row.get("neck", 0.0)
		s.head_scale = row.get("head", 1.0)
		s.base_pitch = row.get("pitch", 1.0)
		s.wanders = row.get("wanders", true)
		s.wander_speed = row.get("speed", 28.0)
		var path: String = "res://resources/species/%s.tres" % row["id"]
		var err: Error = ResourceSaver.save(s, path)
		if err != OK:
			print(path, " ", error_string(err))
		db.species.append(load(path) as SpeciesData)
	print("species: ", db.species.size(), " db ", error_string(ResourceSaver.save(db, "res://resources/species_db.tres")))
	quit()
