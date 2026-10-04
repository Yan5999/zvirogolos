class_name ZooUI
extends CanvasLayer
## Меню «Зоопарк»: список открытых зверей — переименовать, послушать,
## перезаписать голос, отпустить (удалить). Строки переиспользуются.

signal record_requested(id: String)
signal closed

const ENTRY_SCENE: PackedScene = preload("res://scenes/ui/zoo_entry.tscn")

@onready var progress_label: Label = %ProgressLabel
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var list: VBoxContainer = %List
@onready var empty_label: Label = %EmptyLabel
@onready var close_button: Button = %CloseButton
@onready var confirm_dialog: ConfirmationDialog = %ConfirmDialog

var _rows: Array[ZooEntry] = []
var _pending_delete: String = ""


func _ready() -> void:
	visible = false
	close_button.pressed.connect(close)
	confirm_dialog.confirmed.connect(_on_delete_confirmed)
	GameState.animal_updated.connect(_on_data_changed)
	GameState.animal_discovered.connect(_on_data_changed)
	GameState.animal_forgotten.connect(_on_data_changed)


func is_open() -> bool:
	return visible


func open() -> void:
	refresh()
	visible = true
	get_tree().paused = true
	AudioManager.play_ui(&"open")
	if not _rows.is_empty() and _rows[0].visible:
		if _rows[0].play_button.disabled:
			_rows[0].record_button.grab_focus()
		else:
			_rows[0].play_button.grab_focus()
	else:
		close_button.grab_focus()


func close() -> void:
	if not visible:
		return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused:
		focused.release_focus()  # чтобы LineEdit успел применить переименование
	AudioManager.stop_preview()
	visible = false
	get_tree().paused = false
	AudioManager.play_ui(&"close")
	closed.emit()


func refresh() -> void:
	var recs: Array[Dictionary] = GameState.sorted_records()
	var found: int = recs.size()
	var total: int = GameState.total()
	progress_label.text = "Знайдено: %d / %d" % [found, total]
	progress_bar.max_value = total
	progress_bar.value = found
	while _rows.size() < found:
		var row: ZooEntry = ENTRY_SCENE.instantiate() as ZooEntry
		list.add_child(row)
		row.play_requested.connect(_on_play)
		row.record_requested.connect(_on_record)
		row.delete_requested.connect(_on_delete)
		row.rename_requested.connect(_on_rename)
		AudioManager.attach_click_sounds(row.record_button)
		AudioManager.attach_click_sounds(row.delete_button)
		_rows.append(row)
	for i: int in _rows.size():
		var row: ZooEntry = _rows[i]
		row.visible = i < found
		if i < found:
			var id: String = recs[i]["id"]
			row.setup(recs[i], GameState.species_of(id), GameState.has_voice(id))
	empty_label.visible = found == 0


func _on_data_changed(_id: String) -> void:
	if visible:
		refresh()


func _input(event: InputEvent) -> void:
	if not visible or confirm_dialog.visible:
		return
	var typing: bool = get_viewport().gui_get_focus_owner() is LineEdit
	if event.is_action_pressed(&"ui_cancel") or (event.is_action_pressed(&"open_zoo") and not typing):
		get_viewport().set_input_as_handled()
		close()


func _on_play(id: String) -> void:
	var stream: AudioStreamWAV = GameState.get_voice(id)
	if stream:
		AudioManager.play_preview(stream, GameState.species_of(id).base_pitch)


func _on_record(id: String) -> void:
	AudioManager.stop_preview()
	visible = false
	record_requested.emit(id)


func _on_rename(id: String, new_name: String) -> void:
	GameState.rename(id, new_name)


func _on_delete(id: String) -> void:
	_pending_delete = id
	confirm_dialog.dialog_text = "Відпустити «%s»?\nЗапис голосу буде видалено, а звір знову сховається у схованці." % GameState.get_record(id).get("name", "")
	confirm_dialog.popup_centered()


func _on_delete_confirmed() -> void:
	if _pending_delete.is_empty():
		return
	GameState.forget(_pending_delete)
	_pending_delete = ""
	AudioManager.play_ui(&"delete")
	refresh()
	close_button.grab_focus()
