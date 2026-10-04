class_name SettingsPanel
extends Control
## Настройки: громкость (Master / Голоса / Интерфейс через шины AudioServer),
## устройство ввода (микрофон), полноэкранный режим.

signal closed

@onready var master_slider: HSlider = %MasterSlider
@onready var voices_slider: HSlider = %VoicesSlider
@onready var ui_slider: HSlider = %UiSlider
@onready var device_option: OptionButton = %DeviceOption
@onready var fullscreen_check: CheckButton = %FullscreenCheck
@onready var back_button: Button = %BackButton


func _ready() -> void:
	visible = false
	master_slider.value_changed.connect(func(v: float) -> void: AudioManager.set_bus_volume(AudioManager.BUS_MASTER, v))
	voices_slider.value_changed.connect(func(v: float) -> void: AudioManager.set_bus_volume(AudioManager.BUS_VOICES, v))
	ui_slider.value_changed.connect(func(v: float) -> void: AudioManager.set_bus_volume(AudioManager.BUS_UI, v))
	ui_slider.drag_ended.connect(func(_c: bool) -> void: AudioManager.play_ui(&"click"))
	voices_slider.drag_ended.connect(func(_c: bool) -> void: AudioManager.play_ui(&"click"))
	device_option.item_selected.connect(_on_device_selected)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	back_button.pressed.connect(close)
	AudioManager.attach_click_sounds(self)


func open() -> void:
	master_slider.set_value_no_signal(AudioManager.get_bus_volume(AudioManager.BUS_MASTER))
	voices_slider.set_value_no_signal(AudioManager.get_bus_volume(AudioManager.BUS_VOICES))
	ui_slider.set_value_no_signal(AudioManager.get_bus_volume(AudioManager.BUS_UI))
	device_option.clear()
	var devices: PackedStringArray = AudioManager.input_devices()
	for d: String in devices:
		device_option.add_item(d)
		if d == AudioServer.input_device:
			device_option.select(device_option.item_count - 1)
	if devices.is_empty():
		device_option.add_item("Мікрофон не знайдено")
		device_option.disabled = true
	else:
		device_option.disabled = false
	fullscreen_check.set_pressed_no_signal(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	visible = true
	master_slider.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _on_device_selected(index: int) -> void:
	AudioManager.set_input_device(device_option.get_item_text(index))


func _on_fullscreen_toggled(on: bool) -> void:
	apply_fullscreen(on)
	SaveManager.set_setting("video", "fullscreen", on)


static func apply_fullscreen(on: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
