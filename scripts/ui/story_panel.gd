class_name StoryPanel
extends CanvasLayer
## Просте сюжетне вікно (інтро, фінал). Ставить гру на паузу, поки відкрите.

signal closed

var _title: Label
var _body: Label
var _button: Button


func _init() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.08, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 30)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_body = Label.new()
	_body.add_theme_font_size_override("font_size", 18)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(520, 0)
	box.add_child(_body)
	_button = Button.new()
	_button.custom_minimum_size = Vector2(200, 44)
	_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_button.pressed.connect(close)
	box.add_child(_button)


func open(title: String, body: String, button_text: String = "Далі") -> void:
	_title.text = title
	_body.text = body
	_button.text = button_text
	visible = true
	get_tree().paused = true
	AudioManager.play_ui(&"open")
	_button.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false
	AudioManager.play_ui(&"close")
	closed.emit()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
