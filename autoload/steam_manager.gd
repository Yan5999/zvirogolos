extends Node
## Необязательная интеграция Steam через GodotSteam (GDExtension).
## Если расширение не установлено или Steam не запущен — всё молча отключается,
## игра работает как обычно. Вызовы идут через call(), чтобы скрипт парсился без GodotSteam.

## Имена достижений — заведите такие же в Steamworks (App Admin → Stats & Achievements).
const ACH_FIRST_FIND: String = "ACH_FIRST_FIND"
const ACH_FIRST_VOICE: String = "ACH_FIRST_VOICE"
const ACH_FULL_ZOO: String = "ACH_FULL_ZOO"

var enabled: bool = false
var _steam: Object = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	if not Engine.has_singleton("Steam"):
		print_verbose("SteamManager: GodotSteam не знайдено, Steam вимкнено")
		return
	_steam = Engine.get_singleton("Steam")
	var res: Variant = _steam.call("steamInitEx")
	if typeof(res) == TYPE_DICTIONARY and int((res as Dictionary).get("status", -1)) == 0:
		enabled = true
		set_process(true)
		GameState.animal_discovered.connect(_on_discovered)
		GameState.animal_updated.connect(_on_updated)
		print("SteamManager: Steam ініціалізовано")
	else:
		push_warning("SteamManager: не вдалося ініціалізувати Steam: %s" % str(res))


func _process(_delta: float) -> void:
	_steam.call("run_callbacks")


func unlock(achievement: String) -> void:
	if not enabled:
		return
	_steam.call("setAchievement", achievement)
	_steam.call("storeStats")


func _on_discovered(_id: String) -> void:
	unlock(ACH_FIRST_FIND)
	if GameState.found_count() >= GameState.total():
		unlock(ACH_FULL_ZOO)


func _on_updated(id: String) -> void:
	if GameState.has_voice(id):
		unlock(ACH_FIRST_VOICE)
