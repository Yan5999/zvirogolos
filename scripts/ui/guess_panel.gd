class_name GuessPanel
extends ModalPanel
## Мінігра «Вгадай голос»: звучить записаний голос одного зі звірів, треба обрати, чий він.
## Потрібні голоси щонайменше трьох звірів. Серія правильних відповідей дає досягнення.

const MIN_VOICED: int = 3
const OPTIONS: int = 4

var _prompt: Label
var _info: Label
var _score: Label
var _replay: Button
var _next: Button
var _buttons: Array[Button] = []
var _option_ids: Array[String] = []
var _target: String = ""
var _last_target: String = ""
var _answered: bool = false
var streak: int = 0
var correct_index: int = -1


func _init() -> void:
	panel_size = Vector2(640, 520)


func _build_content() -> void:
	title_label.text = "Вгадай голос"
	_prompt = Label.new()
	_prompt.add_theme_font_size_override("font_size", 22)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_prompt)
	_replay = Button.new()
	_replay.text = "▶ Послухати ще раз"
	_replay.custom_minimum_size = Vector2(240, 48)
	_replay.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_replay.pressed.connect(_play_current)
	content.add_child(_replay)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	content.add_child(grid)
	for i: int in OPTIONS:
		var b: Button = Button.new()
		b.custom_minimum_size = Vector2(0, 56)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.pressed.connect(answer.bind(i))
		grid.add_child(b)
		_buttons.append(b)
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 18)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_info)
	_next = Button.new()
	_next.text = "Далі"
	_next.custom_minimum_size = Vector2(200, 46)
	_next.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_next.pressed.connect(new_round)
	content.add_child(_next)
	_score = Label.new()
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_score)


func _refresh() -> void:
	streak = 0
	new_round()


func can_play() -> bool:
	return GameState.voiced_count() >= MIN_VOICED


## Нова загадка. Викликається при відкритті та кнопкою «Далі».
func new_round() -> void:
	_answered = false
	_next.visible = false
	_info.text = ""
	for b: Button in _buttons:
		b.modulate = Color.WHITE
		b.disabled = false
	if not can_play():
		_prompt.text = "Для гри потрібні голоси щонайменше трьох звірів.\nЗаписано: %d. Знайди звірів і запиши їхні голоси!" % GameState.voiced_count()
		_replay.visible = false
		for b: Button in _buttons:
			b.visible = false
		_update_score()
		return
	_replay.visible = true
	var voiced: Array[String] = []
	var others: Array[String] = []
	for id: String in GameState.records:
		if GameState.has_voice(id):
			voiced.append(id)
		others.append(id)
	voiced.shuffle()
	_target = voiced[0]
	if _target == _last_target and voiced.size() > 1:
		_target = voiced[1]
	_last_target = _target
	var target_name: String = String(GameState.get_record(_target).get("name", ""))
	others.shuffle()
	_option_ids = [_target]
	var used_names: Array[String] = [target_name]
	for id: String in others:
		if _option_ids.size() >= OPTIONS:
			break
		var n: String = String(GameState.get_record(id).get("name", ""))
		if id != _target and not used_names.has(n):
			_option_ids.append(id)
			used_names.append(n)
	_option_ids.shuffle()
	correct_index = _option_ids.find(_target)
	for i: int in OPTIONS:
		var b: Button = _buttons[i]
		b.visible = i < _option_ids.size()
		if b.visible:
			b.text = String(GameState.get_record(_option_ids[i]).get("name", ""))
	_prompt.text = "Чий це голос?"
	_update_score()
	_play_current()


func _play_current() -> void:
	if _target.is_empty():
		return
	var stream: AudioStreamWAV = GameState.get_voice(_target)
	var sp: SpeciesData = GameState.species_of(_target)
	if stream and sp:
		AudioManager.play_preview(stream, sp.base_pitch)


## Відповідь гравця (індекс кнопки).
func answer(index: int) -> void:
	if _answered or index < 0 or index >= _option_ids.size():
		return
	_answered = true
	var ok: bool = index == correct_index
	streak = streak + 1 if ok else 0
	GameState.record_guess(ok, streak)
	for b: Button in _buttons:
		b.disabled = true
	_buttons[correct_index].modulate = Color(0.55, 1.0, 0.6)
	if ok:
		_info.text = "Правильно! Серія: %d" % streak
		AudioManager.play_ui(&"save")
	else:
		_buttons[index].modulate = Color(1.0, 0.5, 0.5)
		_info.text = "Ні, це був(-ла) %s" % _buttons[correct_index].text
		AudioManager.play_ui(&"error")
	_next.visible = true
	_next.grab_focus()
	_update_score()


func _update_score() -> void:
	_score.text = "Серія: %d  ·  Рекорд: %d  ·  Правильних: %d з %d" % [
		streak, int(GameState.stats["guess_best"]), int(GameState.stats["guess_correct"]), int(GameState.stats["guess_total"])]
