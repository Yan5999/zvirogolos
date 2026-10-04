extends Control
## Boot: autoload'ы уже загружены (сейв, мир). Переходим в главное меню.

const MAIN_MENU_SCENE: String = "res://scenes/main_menu/main_menu.tscn"


func _ready() -> void:
	SettingsPanel.apply_fullscreen(bool(SaveManager.get_setting("video", "fullscreen", false)))
	await get_tree().process_frame
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
