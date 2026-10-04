extends Node
## Центральное состояние: мир, виды, точки укрытий, открытые животные (записи зоопарка).
## Общается с остальными через сигналы; диском занимается SaveManager.

signal animal_discovered(id: String)
signal animal_updated(id: String)
signal animal_forgotten(id: String)
signal progress_changed(found: int, total: int)

const WORLD_SEED: int = 424242
const SPECIES_DB: SpeciesDatabase = preload("res://resources/species_db.tres")
## Сколько укрытий в каждом биоме (порядок WorldGen.Biome). Сумма = 30.
const SPOTS_PER_BIOME: Array[int] = [8, 7, 7, 8]
const MAX_NAME_LENGTH: int = 24

var world_gen: WorldGen = WorldGen.new()
var player_position: Vector2 = Vector2.ZERO
var species_by_id: Dictionary[StringName, SpeciesData] = {}
## Массив словарей {id, biome, cell, position, species}
var spots: Array[Dictionary] = []
var _spot_by_id: Dictionary[String, Dictionary] = {}
## Открытые животные: id -> {id, species, name, discovered_at, voice, position}
var records: Dictionary[String, Dictionary] = {}
var _voice_cache: Dictionary[String, AudioStreamWAV] = {}


func _ready() -> void:
	for s: SpeciesData in SPECIES_DB.species:
		species_by_id[s.id] = s
	world_gen.generate(WORLD_SEED)
	_build_spots()
	_load()


func _build_spots() -> void:
	spots = world_gen.generate_spots(SPOTS_PER_BIOME)
	var per_biome_counter: Dictionary[int, int] = {}
	for spot: Dictionary in spots:
		var biome: int = spot["biome"]
		var options: Array[SpeciesData] = SPECIES_DB.by_biome(biome)
		var k: int = per_biome_counter.get(biome, 0)
		per_biome_counter[biome] = k + 1
		spot["species"] = options[k % options.size()].id if not options.is_empty() else SPECIES_DB.species[0].id
		_spot_by_id[spot["id"]] = spot


# --- Запросы ----------------------------------------------------------------

func total() -> int:
	return spots.size()


func found_count() -> int:
	return records.size()


func get_spot(id: String) -> Dictionary:
	return _spot_by_id.get(id, {})


func get_species(species_id: StringName) -> SpeciesData:
	return species_by_id.get(species_id, null)


func species_of(id: String) -> SpeciesData:
	var spot: Dictionary = get_spot(id)
	if spot.is_empty():
		return null
	return get_species(spot["species"])


func is_discovered(id: String) -> bool:
	return records.has(id)


func get_record(id: String) -> Dictionary:
	return records.get(id, {})


## Записи в порядке открытия (для меню зоопарка).
func sorted_records() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for rec: Dictionary in records.values():
		list.append(rec)
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("discovered_at", "")) < String(b.get("discovered_at", "")))
	return list


# --- Изменения --------------------------------------------------------------

func discover(id: String) -> void:
	if records.has(id) or not _spot_by_id.has(id):
		return
	var sp: SpeciesData = species_of(id)
	var pos: Vector2 = _spot_by_id[id]["position"]
	records[id] = {
		"id": id,
		"species": String(sp.id),
		"name": sp.display_name,
		"named": false,
		"discovered_at": Time.get_datetime_string_from_system(false, true),
		"voice": "",
		"position": [pos.x, pos.y],
	}
	save()
	animal_discovered.emit(id)
	progress_changed.emit(found_count(), total())


func rename(id: String, new_name: String) -> void:
	if not records.has(id):
		return
	var clean: String = sanitize_name(new_name)
	if clean.is_empty():
		return
	records[id]["name"] = clean
	records[id]["named"] = true
	save()
	animal_updated.emit(id)


static func sanitize_name(raw: String) -> String:
	return raw.strip_edges().replace("\n", " ").left(MAX_NAME_LENGTH)


## Сохраняет голос (.wav) и привязывает к записи.
func set_voice(id: String, stream: AudioStreamWAV) -> bool:
	if not records.has(id) or stream == null:
		return false
	var file_name: String = SaveManager.save_voice(id, stream)
	if file_name.is_empty():
		return false
	records[id]["voice"] = file_name
	records[id]["voice_updated"] = Time.get_datetime_string_from_system(false, true)
	_voice_cache[id] = stream
	save()
	animal_updated.emit(id)
	return true


func has_voice(id: String) -> bool:
	return not String(get_record(id).get("voice", "")).is_empty()


## Голос животного (лениво загружается с диска и кешируется).
func get_voice(id: String) -> AudioStreamWAV:
	if _voice_cache.has(id):
		return _voice_cache[id]
	var file_name: String = String(get_record(id).get("voice", ""))
	if file_name.is_empty():
		return null
	var stream: AudioStreamWAV = SaveManager.load_voice(file_name)
	if stream:
		_voice_cache[id] = stream
	return stream


## Убирает животное из зоопарка: оно снова прячется в укрытии, запись удаляется.
func forget(id: String) -> void:
	if not records.has(id):
		return
	SaveManager.delete_voice(String(records[id].get("voice", "")))
	records.erase(id)
	_voice_cache.erase(id)
	save()
	animal_forgotten.emit(id)
	progress_changed.emit(found_count(), total())


func update_animal_position(id: String, pos: Vector2) -> void:
	if records.has(id):
		records[id]["position"] = [pos.x, pos.y]


func reset_progress() -> void:
	records.clear()
	_voice_cache.clear()
	player_position = world_gen.start_position()
	SaveManager.delete_save()
	progress_changed.emit(0, total())


# --- Сохранение -------------------------------------------------------------

func save() -> void:
	SaveManager.save_game({
		"player": [player_position.x, player_position.y],
		"animals": records.values(),
	})


func _load() -> void:
	var data: Dictionary = SaveManager.load_game()
	player_position = world_gen.start_position()
	if data.has("player"):
		var p: Array = data["player"]
		var pos: Vector2 = Vector2(float(p[0]), float(p[1]))
		if world_gen.is_walkable_pos(pos):
			player_position = pos
	records.clear()
	var list: Array = data.get("animals", [])
	for item: Variant in list:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var rec: Dictionary = item
		var id: String = String(rec.get("id", ""))
		if not _spot_by_id.has(id):
			continue
		rec["species"] = String(_spot_by_id[id]["species"])
		rec["name"] = sanitize_name(String(rec.get("name", "")))
		# Неназваний звір завжди показує актуальну назву виду (напр. після зміни мови).
		if String(rec["name"]).is_empty() or not bool(rec.get("named", false)):
			rec["name"] = species_of(id).display_name
		records[id] = rec


static func record_position(rec: Dictionary, fallback: Vector2) -> Vector2:
	var p: Variant = rec.get("position", null)
	if typeof(p) == TYPE_ARRAY and (p as Array).size() >= 2:
		return Vector2(float(p[0]), float(p[1]))
	return fallback
