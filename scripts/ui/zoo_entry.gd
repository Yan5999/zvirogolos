class_name ZooEntry
extends PanelContainer
## Строка списка зоопарка. Переиспользуется (пул в ZooUI), данные задаются через setup().

signal play_requested(id: String)
signal record_requested(id: String)
signal delete_requested(id: String)
signal rename_requested(id: String, new_name: String)

var animal_id: String = ""
var _species: SpeciesData
var _current_name: String = ""

@onready var icon: Control = %Icon
@onready var name_edit: LineEdit = %NameEdit
@onready var meta_label: Label = %MetaLabel
@onready var play_button: Button = %PlayButton
@onready var record_button: Button = %RecordButton
@onready var delete_button: Button = %DeleteButton


func _ready() -> void:
	icon.draw.connect(_on_icon_draw)
	name_edit.max_length = GameState.MAX_NAME_LENGTH
	name_edit.text_submitted.connect(func(_t: String) -> void: _commit_name())
	name_edit.focus_exited.connect(_commit_name)
	play_button.pressed.connect(func() -> void: play_requested.emit(animal_id))
	record_button.pressed.connect(func() -> void: record_requested.emit(animal_id))
	delete_button.pressed.connect(func() -> void: delete_requested.emit(animal_id))


func setup(record: Dictionary, species: SpeciesData, has_voice: bool) -> void:
	animal_id = String(record.get("id", ""))
	_species = species
	_current_name = String(record.get("name", ""))
	name_edit.text = _current_name
	var date: String = String(record.get("discovered_at", "")).replace("T", " ").left(16)
	meta_label.text = "%s · знайдено %s · %s" % [species.display_name, date, "голос записано" if has_voice else "без голосу"]
	play_button.disabled = not has_voice
	record_button.text = "Перезаписати" if has_voice else "Записати"
	icon.queue_redraw()


func _commit_name() -> void:
	var clean: String = GameState.sanitize_name(name_edit.text)
	if clean.is_empty():
		name_edit.text = _current_name
		return
	if clean != _current_name:
		_current_name = clean
		rename_requested.emit(animal_id, clean)


func _on_icon_draw() -> void:
	if _species == null:
		return
	var c: Vector2 = icon.size * 0.5 + Vector2(0, 4)
	DrawUtil.draw_ellipse(icon, c, Vector2(15, 11), _species.body_color)
	DrawUtil.draw_ellipse(icon, c + Vector2(2, 4), Vector2(9, 6), _species.belly_color)
	icon.draw_circle(c + Vector2(9, -10), 8, _species.body_color)
	icon.draw_circle(c + Vector2(12, -11), 2.5, Color.WHITE)
	icon.draw_circle(c + Vector2(13, -11), 1.3, Color("1e1e24"))
	icon.draw_circle(c + Vector2(-12, 6), 3, _species.accent_color)
