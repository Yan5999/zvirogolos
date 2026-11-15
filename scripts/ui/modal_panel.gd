class_name ModalPanel
extends CanvasLayer
## Основа повноекранних вікон (альбом, досягнення, вгадай голос): затемнення, панель із заголовком
## і кнопкою «Закрити». Ставить гру на паузу, поки відкрите. Нащадки заповнюють `content`.

signal closed

var panel_size: Vector2 = Vector2(900, 560)
var title_label: Label
var content: VBoxContainer
var close_button: Button


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.08, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = panel_size
	center.add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	var header: HBoxContainer = HBoxContainer.new()
	box.add_child(header)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	close_button = Button.new()
	close_button.text = "Закрити"
	close_button.custom_minimum_size = Vector2(120, 40)
	close_button.pressed.connect(close)
	header.add_child(close_button)
	content = VBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	box.add_child(content)
	_build_content()


## Перевизначити: створити вміст один раз.
func _build_content() -> void:
	pass


## Перевизначити: оновити вміст перед показом.
func _refresh() -> void:
	pass


func is_open() -> bool:
	return visible


func open() -> void:
	_refresh()
	visible = true
	get_tree().paused = true
	AudioManager.play_ui(&"open")
	close_button.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false
	AudioManager.stop_preview()
	AudioManager.play_ui(&"close")
	closed.emit()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
