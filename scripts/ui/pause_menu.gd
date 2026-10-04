class_name PauseMenu
extends CanvasLayer
## Пауза: продолжить, зоопарк, настройки, выход в меню.

signal zoo_requested
signal map_requested
signal main_menu_requested

@onready var resume_button: Button = %ResumeButton
@onready var zoo_button: Button = %ZooButton
@onready var map_button: Button = %MapButton
@onready var settings_button: Button = %SettingsButton
@onready var menu_button: Button = %MenuButton
@onready var settings: SettingsPanel = $SettingsPanel


func _ready() -> void:
	visible = false
	resume_button.pressed.connect(close)
	zoo_button.pressed.connect(func() -> void:
		close()
		zoo_requested.emit())
	map_button.pressed.connect(func() -> void:
		close()
		map_requested.emit())
	settings_button.pressed.connect(settings.open)
	settings.closed.connect(settings_button.grab_focus)
	menu_button.pressed.connect(func() -> void: main_menu_requested.emit())
	AudioManager.attach_click_sounds($Center)


func is_open() -> bool:
	return visible


func open() -> void:
	visible = true
	get_tree().paused = true
	AudioManager.play_ui(&"open")
	resume_button.grab_focus()


func close() -> void:
	if not visible:
		return
	settings.close()
	visible = false
	get_tree().paused = false


func _input(event: InputEvent) -> void:
	if not visible or settings.visible:
		return
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
