class_name RecordDialog
extends CanvasLayer
## Окно «имя + голос»: ввод имени, запись с микрофона (до 5 с) с индикатором уровня,
## предпрослушивание, перезапись, загрузка .wav из файла (если микрофона нет/нет доступа),
## сохранение. На время открытия ставит дерево на паузу.

signal closed(animal_id: String, saved: bool)

const MAX_SECONDS: float = VoiceProcessing.MAX_SECONDS
## Если за это время с микрофона не пришло ни одного кадра — показываем подсказку.
## На Windows (WASAPI) запуск входного потока может занимать 1–2 с, поэтому запас большой,
## а предупреждение снимается само, как только звук пошёл.
const NO_STREAM_TIMEOUT: float = 3.0
const COLOR_OK: Color = Color("cfe8c8")
const COLOR_WARN: Color = Color("ffd27a")
const COLOR_ERR: Color = Color("ff8f8f")

@onready var title_label: Label = %TitleLabel
@onready var info_label: Label = %InfoLabel
@onready var name_edit: LineEdit = %NameEdit
@onready var record_button: Button = %RecordButton
@onready var time_label: Label = %TimeLabel
@onready var level_bar: ProgressBar = %LevelBar
@onready var time_bar: ProgressBar = %TimeBar
@onready var status_label: Label = %StatusLabel
@onready var play_button: Button = %PlayButton
@onready var load_button: Button = %LoadButton
@onready var cancel_button: Button = %CancelButton
@onready var save_button: Button = %SaveButton
@onready var file_dialog: FileDialog = %FileDialog

var animal_id: String = ""
var _species: SpeciesData
var _take: AudioStreamWAV
var _recording: bool = false
var _rec_time: float = 0.0
var _open_time: float = 0.0
var _mic_ok: bool = true
var _stream_warned: bool = false


func _ready() -> void:
	visible = false
	set_process(false)
	record_button.pressed.connect(_on_record_pressed)
	play_button.pressed.connect(_on_play_pressed)
	load_button.pressed.connect(_on_load_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	save_button.pressed.connect(_on_save_pressed)
	name_edit.text_submitted.connect(func(_t: String) -> void: record_button.grab_focus())
	name_edit.max_length = GameState.MAX_NAME_LENGTH
	file_dialog.file_selected.connect(_on_file_selected)
	level_bar.max_value = 1.0
	AudioManager.attach_click_sounds(cancel_button)
	AudioManager.attach_click_sounds(load_button)
	time_bar.max_value = MAX_SECONDS


func is_open() -> bool:
	return visible


func open(id: String, is_new: bool) -> void:
	animal_id = id
	_species = GameState.species_of(id)
	var rec: Dictionary = GameState.get_record(id)
	title_label.text = ("Новий звір: %s!" % _species.display_name) if is_new else ("%s — %s" % [rec.get("name", ""), _species.display_name])
	info_label.text = "%s (%s)\n%s" % [_species.display_name, _species.latin_name, _species.description] if not _species.latin_name.is_empty() else _species.description
	name_edit.placeholder_text = _species.display_name
	name_edit.text = String(rec.get("name", "")) if bool(rec.get("named", false)) else ""
	_take = null
	_recording = false
	_rec_time = 0.0
	_open_time = 0.0
	_stream_warned = false
	time_bar.value = 0.0
	_update_time_label()
	visible = true
	get_tree().paused = true
	set_process(true)
	_mic_ok = AudioManager.has_input_device()
	if _mic_ok:
		AudioManager.open_mic()
		_set_status("Вигадайте ім'я та запишіть голос звіра (до %d секунд)." % int(MAX_SECONDS), COLOR_OK)
	else:
		_show_mic_problem("Мікрофон не знайдено або введення звуку вимкнено.")
	_update_buttons()
	AudioManager.play_ui(&"open")
	name_edit.grab_focus()


func close(saved: bool) -> void:
	if not visible:
		return
	if _recording:
		_recording = false
		AudioManager.stop_recording()
	AudioManager.close_mic()
	AudioManager.stop_preview()
	visible = false
	set_process(false)
	get_tree().paused = false
	if not saved:
		AudioManager.play_ui(&"close")
	closed.emit(animal_id, saved)


func _process(delta: float) -> void:
	_open_time += delta
	var lvl: float = AudioManager.poll_mic_level()
	level_bar.value = sqrt(lvl)
	if _mic_ok:
		var frames: int = AudioManager.mic_frames_received()
		if not _stream_warned and frames == 0 and _open_time > NO_STREAM_TIMEOUT:
			# Только предупреждаем: кнопку записи не блокируем, поток может стартовать позже.
			_stream_warned = true
			_show_mic_problem("З мікрофона поки не надходить звук.")
		elif _stream_warned and frames > 0:
			_stream_warned = false
			_set_status("Мікрофон запрацював. Можна записувати!", COLOR_OK)
			record_button.grab_focus()
	if _recording:
		_rec_time += delta
		time_bar.value = _rec_time
		_update_time_label()
		if _rec_time >= MAX_SECONDS:
			_stop_recording()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel") and not file_dialog.visible:
		get_viewport().set_input_as_handled()
		close(false)


# --- Запись ----------------------------------------------------------------------

func _on_record_pressed() -> void:
	if _recording:
		_stop_recording()
	else:
		_start_recording()


func _start_recording() -> void:
	AudioManager.stop_preview()
	AudioManager.play_ui(&"record")
	AudioManager.start_recording()
	_recording = true
	_rec_time = 0.0
	_set_status("Іде запис… Говоріть, гарчіть, нявкайте!", COLOR_WARN)
	_update_buttons()


func _stop_recording() -> void:
	if not _recording:
		return
	_recording = false
	var raw: AudioStreamWAV = AudioManager.stop_recording()
	_apply_take(raw, true)
	_update_buttons()


func _apply_take(raw: AudioStreamWAV, from_mic: bool) -> void:
	var res: VoiceProcessing.Result = VoiceProcessing.process(raw)
	if res.ok:
		_take = res.stream
		_set_status("Готово: %.1f с (тишу обрізано, гучність вирівняно). Прослухайте та збережіть." % res.duration, COLOR_OK)
		AudioManager.play_preview(_take, _species.base_pitch)
	elif res.silent and from_mic:
		_show_mic_problem("Запис вийшов беззвучним.")
	else:
		AudioManager.play_ui(&"error")
		_set_status(res.message, COLOR_ERR)
	_update_buttons()


func _show_mic_problem(reason: String) -> void:
	var hint: String = "Перевірте, що мікрофон підключено і застосунку дозволено доступ"
	if OS.get_name() == "Windows":
		hint += " (Параметри → Конфіденційність і захист → Мікрофон → «Дозволити класичним програмам доступ до мікрофона»)"
	elif OS.get_name() == "macOS":
		hint += " (Системні параметри → Конфіденційність і безпека → Мікрофон)"
	_set_status("%s %s. Або натисніть «Завантажити файл…» і оберіть готовий .wav." % [reason, hint], COLOR_ERR)
	load_button.grab_focus()


# --- Кнопки ---------------------------------------------------------------------

func _on_play_pressed() -> void:
	var s: AudioStreamWAV = _take if _take else GameState.get_voice(animal_id)
	if s:
		AudioManager.play_preview(s, _species.base_pitch)


func _on_load_pressed() -> void:
	AudioManager.play_ui(&"click")
	file_dialog.popup_centered_ratio(0.7)


func _on_file_selected(path: String) -> void:
	var w: AudioStreamWAV = SaveManager.load_wav_file(path)
	if w == null:
		AudioManager.play_ui(&"error")
		_set_status("Не вдалося прочитати файл: %s" % path.get_file(), COLOR_ERR)
		return
	_apply_take(w, false)


func _on_cancel_pressed() -> void:
	close(false)


func _on_save_pressed() -> void:
	if _recording:
		_stop_recording()
	var final_name: String = GameState.sanitize_name(name_edit.text)
	if final_name.is_empty():
		final_name = _species.display_name
	GameState.rename(animal_id, final_name)
	if _take and not GameState.set_voice(animal_id, _take):
		AudioManager.play_ui(&"error")
		_set_status("Не вдалося зберегти звук на диск.", COLOR_ERR)
		return
	AudioManager.play_ui(&"save")
	close(true)


func _update_buttons() -> void:
	record_button.disabled = not _mic_ok
	if _recording:
		record_button.text = "Стоп"
	elif _take or GameState.has_voice(animal_id):
		record_button.text = "Перезаписати"
	else:
		record_button.text = "Записати голос"
	play_button.disabled = _recording or (_take == null and not GameState.has_voice(animal_id))
	load_button.disabled = _recording
	save_button.disabled = _recording


func _update_time_label() -> void:
	time_label.text = "%.1f / %.0f с" % [_rec_time, MAX_SECONDS]


func _set_status(text: String, color: Color) -> void:
	status_label.text = text
	status_label.add_theme_color_override("font_color", color)
