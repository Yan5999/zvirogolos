extends Node
## Персистентность: user://save.json (метаданные), user://voices/*.wav (записи),
## user://settings.cfg (громкость и прочие настройки). Ничего не знает об игровой логике.

signal save_failed(message: String)

const SAVE_PATH: String = "user://save.json"
const VOICES_DIR: String = "user://voices/"
const SETTINGS_PATH: String = "user://settings.cfg"
const SAVE_VERSION: int = 1

var settings: ConfigFile = ConfigFile.new()


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(VOICES_DIR)
	if settings.load(SETTINGS_PATH) != OK:
		settings = ConfigFile.new()


# --- Игра -------------------------------------------------------------------

func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var text: String = FileAccess.get_file_as_string(SAVE_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("save.json пошкоджено, починаємо заново")
		return {}
	return parsed as Dictionary


func save_game(data: Dictionary) -> bool:
	data["version"] = SAVE_VERSION
	data["saved_at"] = Time.get_datetime_string_from_system()
	var tmp_path: String = SAVE_PATH + ".tmp"
	var f: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		var msg: String = "Не вдалося зберегти гру: %s" % error_string(FileAccess.get_open_error())
		push_error(msg)
		save_failed.emit(msg)
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	return DirAccess.rename_absolute(tmp_path, SAVE_PATH) == OK


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	var dir: DirAccess = DirAccess.open(VOICES_DIR)
	if dir:
		for file_name: String in dir.get_files():
			if file_name.get_extension() == "wav":
				dir.remove(file_name)


# --- Голоса -----------------------------------------------------------------

## Сохраняет запись и возвращает имя файла (относительно VOICES_DIR) или "".
func save_voice(animal_id: String, stream: AudioStreamWAV) -> String:
	var file_name: String = "%s.wav" % animal_id
	var err: Error = stream.save_to_wav(VOICES_DIR + file_name)
	if err != OK:
		var msg: String = "Не вдалося зберегти звук: %s" % error_string(err)
		push_error(msg)
		save_failed.emit(msg)
		return ""
	return file_name


func load_voice(file_name: String) -> AudioStreamWAV:
	if file_name.is_empty():
		return null
	return load_wav_file(VOICES_DIR + file_name)


func delete_voice(file_name: String) -> void:
	if file_name.is_empty():
		return
	var path: String = VOICES_DIR + file_name
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## Загружает произвольный .wav (свои записи или файл пользователя).
func load_wav_file(path: String) -> AudioStreamWAV:
	if not FileAccess.file_exists(path):
		return null
	# Явно отключаем сжатие (QOA/ADPCM), чтобы данные оставались PCM и их можно было обработать.
	var stream: AudioStreamWAV = AudioStreamWAV.load_from_file(path, {"compress/mode": 0})
	return stream


# --- Настройки --------------------------------------------------------------

func get_setting(section: String, key: String, default: Variant) -> Variant:
	return settings.get_value(section, key, default)


func set_setting(section: String, key: String, value: Variant) -> void:
	settings.set_value(section, key, value)
	settings.save(SETTINGS_PATH)
