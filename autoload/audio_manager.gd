extends Node
## Звук: шины и громкость, пул пространственных голосов животных, микрофон (запись + индикатор уровня), предпрослушивание,
## синтезированные звуки интерфейса.

const BUS_MASTER: StringName = &"Master"
const BUS_VOICES: StringName = &"Voices"
const BUS_UI: StringName = &"UI"
const BUS_RECORD: StringName = &"Record"
const VOLUME_BUSES: Array[StringName] = [BUS_MASTER, BUS_VOICES, BUS_UI]
const UI_PLAYERS: int = 3
## Не больше стольких голосов животных одновременно.
const MAX_VOICES: int = 4
## Встроенное затухание AudioStreamPlayer2D: дальше max_distance — тишина.
const VOICE_MAX_DISTANCE: float = 650.0
const VOICE_ATTENUATION: float = 1.6
const VOICE_PANNING: float = 1.2
const SYNTH_RATE: int = 22050

var _record: AudioEffectRecord
var _capture: AudioEffectCapture
var _mic_player: AudioStreamPlayer
var _preview_player: AudioStreamPlayer
var _ui_players: Array[AudioStreamPlayer] = []
var _ui_next: int = 0
var _ui_sounds: Dictionary[StringName, AudioStreamWAV] = {}
var _voice_players: Array[AudioStreamPlayer2D] = []
var _voice_sources: Array[Node2D] = []
var _level: float = 0.0
var _mic_frames: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	for bus: StringName in VOLUME_BUSES:
		set_bus_volume(bus, float(SaveManager.get_setting("audio", String(bus), 0.8)), false)
	var saved_device: String = String(SaveManager.get_setting("audio", "input_device", ""))
	if not saved_device.is_empty() and saved_device in AudioServer.get_input_device_list():
		AudioServer.input_device = saved_device

	_mic_player = _make_player(BUS_RECORD, "MicPlayer")
	_mic_player.stream = AudioStreamMicrophone.new()
	_preview_player = _make_player(BUS_VOICES, "PreviewPlayer")
	for i: int in UI_PLAYERS:
		_ui_players.append(_make_player(BUS_UI, "UiPlayer%d" % i))
	for i: int in MAX_VOICES:
		var vp: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
		vp.name = "VoicePlayer%d" % i
		vp.bus = BUS_VOICES
		vp.max_distance = VOICE_MAX_DISTANCE
		vp.attenuation = VOICE_ATTENUATION
		vp.panning_strength = VOICE_PANNING
		vp.max_polyphony = 1
		vp.finished.connect(_on_voice_finished.bind(i))
		add_child(vp)
		_voice_players.append(vp)
		_voice_sources.append(null)
	set_process(false)
	_build_ui_sounds()


## Останавливаем всё при выходе, чтобы AudioServer не держал playback'и (утечки при quit).
func _exit_tree() -> void:
	stop_all()


func stop_all() -> void:
	if is_recording():
		_record.set_recording_active(false)
	for child: Node in get_children():
		if child is AudioStreamPlayer:
			(child as AudioStreamPlayer).stop()
		elif child is AudioStreamPlayer2D:
			(child as AudioStreamPlayer2D).stop()


func _make_player(bus: StringName, node_name: String) -> AudioStreamPlayer:
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.name = node_name
	p.bus = bus
	add_child(p)
	return p


## Если bus layout не загрузился — создаём шины и эффекты кодом.
func _ensure_buses() -> void:
	for bus: StringName in [BUS_VOICES, BUS_UI, BUS_RECORD]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var idx: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus)
			AudioServer.set_bus_send(idx, BUS_MASTER)
	var rec: int = AudioServer.get_bus_index(BUS_RECORD)
	AudioServer.set_bus_mute(rec, true)  # без обратной связи из колонок
	for e: int in AudioServer.get_bus_effect_count(rec):
		var fx: AudioEffect = AudioServer.get_bus_effect(rec, e)
		if fx is AudioEffectCapture:
			_capture = fx
		elif fx is AudioEffectRecord:
			_record = fx
	if _capture == null:
		_capture = AudioEffectCapture.new()
		_capture.buffer_length = 0.25
		AudioServer.add_bus_effect(rec, _capture, 0)
	if _record == null:
		_record = AudioEffectRecord.new()
		AudioServer.add_bus_effect(rec, _record)
	_record.format = AudioStreamWAV.FORMAT_16_BITS


# --- Громкость ----------------------------------------------------------------

func get_bus_volume(bus: StringName) -> float:
	var idx: int = AudioServer.get_bus_index(bus)
	if idx < 0 or AudioServer.is_bus_mute(idx):
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(idx))


## linear 0..1. Сохраняет в настройки при persist=true.
func set_bus_volume(bus: StringName, linear: float, persist: bool = true) -> void:
	var idx: int = AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	linear = clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
	if persist:
		SaveManager.set_setting("audio", String(bus), linear)


# --- Голоса животных (пул) ------------------------------------------------------

## Проиграть голос в точке source (плеер следует за ним, пока звучит).
## false — если все MAX_VOICES плееров заняты или этот источник уже звучит.
func play_voice_at(stream: AudioStream, source: Node2D, pitch: float = 1.0) -> bool:
	if stream == null or source == null:
		return false
	var slot: int = -1
	for i: int in MAX_VOICES:
		if _voice_players[i].playing:
			if _voice_sources[i] == source:
				return false
		elif slot == -1:
			slot = i
	if slot == -1:
		return false
	var p: AudioStreamPlayer2D = _voice_players[slot]
	p.stream = stream
	p.pitch_scale = clampf(pitch, 0.5, 2.0)
	p.global_position = source.global_position
	_voice_sources[slot] = source
	p.play()
	set_process(true)
	return true


func active_voice_count() -> int:
	var n: int = 0
	for p: AudioStreamPlayer2D in _voice_players:
		if p.playing:
			n += 1
	return n


func stop_voices() -> void:
	for i: int in MAX_VOICES:
		_voice_players[i].stop()
		_voice_sources[i] = null


func _on_voice_finished(slot: int) -> void:
	_voice_sources[slot] = null


func _process(_delta: float) -> void:
	var any: bool = false
	for i: int in MAX_VOICES:
		var p: AudioStreamPlayer2D = _voice_players[i]
		if not p.playing:
			continue
		any = true
		var src: Node2D = _voice_sources[i]
		if is_instance_valid(src):
			p.global_position = src.global_position
		else:
			_voice_sources[i] = null
	if not any:
		set_process(false)


# --- Микрофон -------------------------------------------------------------------

func input_enabled() -> bool:
	return bool(ProjectSettings.get_setting("audio/driver/enable_input", false))


func has_input_device() -> bool:
	return input_enabled() and not AudioServer.get_input_device_list().is_empty()


func input_devices() -> PackedStringArray:
	return AudioServer.get_input_device_list()


func set_input_device(device: String) -> void:
	AudioServer.input_device = device
	SaveManager.set_setting("audio", "input_device", device)


## Открыть поток микрофона (только пока открыт диалог записи).
func open_mic() -> void:
	_mic_frames = 0
	_level = 0.0
	if _capture:
		_capture.clear_buffer()
	if not _mic_player.playing:
		_mic_player.play()


func close_mic() -> void:
	if is_recording():
		_record.set_recording_active(false)
	_mic_player.stop()
	_level = 0.0


func start_recording() -> void:
	open_mic()
	_record.set_recording_active(true)


func stop_recording() -> AudioStreamWAV:
	if not is_recording():
		return null
	_record.set_recording_active(false)
	return _record.get_recording()


func is_recording() -> bool:
	return _record != null and _record.is_recording_active()


## Пиковый уровень микрофона 0..1 (со спадом). Вызывать раз в кадр, пока открыт микрофон.
func poll_mic_level() -> float:
	_level *= 0.86
	if _capture == null:
		return _level
	var n: int = _capture.get_frames_available()
	if n > 0:
		_mic_frames += n
		var buf: PackedVector2Array = _capture.get_buffer(n)
		var pk: float = 0.0
		for f: Vector2 in buf:
			pk = maxf(pk, maxf(absf(f.x), absf(f.y)))
		_level = maxf(_level, pk)
	return _level


## Сколько кадров пришло с микрофона с момента open_mic(). 0 — поток не идёт.
func mic_frames_received() -> int:
	return _mic_frames


# --- Предпрослушивание и UI ----------------------------------------------------

func play_preview(stream: AudioStream, pitch: float = 1.0) -> void:
	_preview_player.stop()
	_preview_player.stream = stream
	_preview_player.pitch_scale = pitch
	_preview_player.play()


func stop_preview() -> void:
	_preview_player.stop()


func is_preview_playing() -> bool:
	return _preview_player.playing


func play_ui(sound: StringName) -> void:
	if not _ui_sounds.has(sound):
		return
	var p: AudioStreamPlayer = _ui_players[_ui_next]
	_ui_next = (_ui_next + 1) % _ui_players.size()
	p.stream = _ui_sounds[sound]
	p.play()


## Подключает щелчок ко всем кнопкам в поддереве (один раз на кнопку).
func attach_click_sounds(root: Node) -> void:
	if root is BaseButton:
		var b: BaseButton = root
		var cb: Callable = play_ui.bind(&"click")
		if not b.pressed.is_connected(cb):
			b.pressed.connect(cb)
	for child: Node in root.get_children():
		attach_click_sounds(child)


func _build_ui_sounds() -> void:
	_ui_sounds[&"click"] = _synth([1046.5], 0.045, 0.25)
	_ui_sounds[&"open"] = _synth([523.25, 783.99], 0.07, 0.3)
	_ui_sounds[&"close"] = _synth([783.99, 523.25], 0.06, 0.25)
	_ui_sounds[&"discover"] = _synth([523.25, 659.25, 783.99, 1046.5], 0.09, 0.35)
	_ui_sounds[&"save"] = _synth([659.25, 987.77], 0.09, 0.3)
	_ui_sounds[&"record"] = _synth([880.0], 0.08, 0.3)
	_ui_sounds[&"delete"] = _synth([392.0, 261.63], 0.1, 0.3)
	_ui_sounds[&"error"] = _synth([220.0, 196.0], 0.12, 0.3, true)


## Простой синтезатор: последовательность нот с экспоненциальным затуханием.
func _synth(notes: Array[float], note_len: float, volume: float, square: bool = false) -> AudioStreamWAV:
	var per_note: int = int(note_len * SYNTH_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(per_note * notes.size() + int(0.05 * SYNTH_RATE))
	samples.fill(0.0)
	for n: int in notes.size():
		var freq: float = notes[n]
		var tail: int = per_note * 2
		for i: int in tail:
			var idx: int = n * per_note + i
			if idx >= samples.size():
				break
			var t: float = float(i) / SYNTH_RATE
			var env: float = minf(1.0, t / 0.004) * exp(-t * 28.0)
			var ph: float = sin(TAU * freq * t)
			var v: float = signf(ph) * 0.5 if square else ph + 0.25 * sin(TAU * freq * 2.0 * t)
			samples[idx] += v * env * volume
	return VoiceProcessing.encode_wav(samples, SYNTH_RATE)
