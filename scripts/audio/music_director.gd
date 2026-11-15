class_name MusicDirector
extends Node
## Диригент: підбирає музику за біомом і порою доби (кросфейд двох плеєрів), веде шари довкілля
## (вітер, вода, листя, цвіркуни) і випадкові голоси природи. Треки генеруються в потоці й кешуються.
## Під час запису з мікрофона все стишується — інакше музика з колонок потрапила б у голос.

const MUSIC_FADE: float = 2.5
const LAYER_FADE: float = 3.0
const DUCK_FADE: float = 0.35
const MUSIC_GAIN: float = 0.8
const MIN_DB: float = -60.0

var _players: Array[AudioStreamPlayer] = []
var _levels: Array[float] = [0.0, 0.0]
var _active: int = -1
var _cache: Dictionary[int, AudioStreamWAV] = {}
var _tasks: Dictionary[int, int] = {}
var _want_key: int = -1
var _playing_key: int = -1

var _layers: Dictionary[StringName, AudioStreamPlayer] = {}
var _layer_level: Dictionary[StringName, float] = {}
var _layer_target: Dictionary[StringName, float] = {}
var _events: Dictionary[StringName, Array] = {}
var _event_player: AudioStreamPlayer
var _event_timer: float = 6.0
var _event_kinds: Array[StringName] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _duck: float = 1.0
var _duck_target: float = 1.0
var _ambient_ready: bool = false
var _rain_level: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	for i: int in 2:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.name = "Music%d" % i
		p.bus = AudioManager.BUS_MUSIC
		p.volume_db = MIN_DB
		add_child(p)
		_players.append(p)
	_event_player = AudioStreamPlayer.new()
	_event_player.name = "EventPlayer"
	_event_player.bus = AudioManager.BUS_AMBIENT
	_event_player.volume_db = -8.0
	add_child(_event_player)


func _exit_tree() -> void:
	stop_all()
	for id: int in _tasks.values():
		WorkerThreadPool.wait_for_task_completion(id)
	_tasks.clear()


func stop_all() -> void:
	set_process(false)
	for p: AudioStreamPlayer in _players:
		p.stop()
		p.stream = null
	for p: AudioStreamPlayer in _layers.values():
		p.stop()
		p.stream = null
	if _event_player:
		_event_player.stop()
		_event_player.stream = null
	_active = -1
	_playing_key = -1
	_want_key = -1


## Задає, що має звучати. in_world=false — тема меню без довкілля.
func set_context(in_world: bool, biome: int, night: bool) -> void:
	var key: int = Synth.track_key(biome, night) if in_world else Synth.MENU_KEY
	_request_track(key)
	if in_world:
		_ensure_ambient()
		_apply_ambient_mix(biome, night)
	else:
		for kind: StringName in _layer_target:
			_layer_target[kind] = 0.0
		_event_kinds = []


func set_duck(on: bool) -> void:
	_duck_target = 0.0 if on else 1.0


## Сила дощу 0..1 (викликає Weather): вмикає шар дощу й трохи приглушує решту довкілля.
func set_rain(level: float) -> void:
	_rain_level = clampf(level, 0.0, 1.0)
	if _rain_level > 0.0:
		_ensure_ambient()


func rain_level() -> float:
	return _rain_level


func play_thunder() -> void:
	if _duck < 0.9 or not _events.has(&"thunder"):
		return
	_event_player.stream = _events[&"thunder"][0]
	_event_player.pitch_scale = _rng.randf_range(0.85, 1.05)
	_event_player.play()


func is_ducked() -> bool:
	return _duck_target < 0.5


## Ключ доріжки, що зараз грає (або -1).
func current_key() -> int:
	return _playing_key


func cached_tracks() -> int:
	return _cache.size()


func _request_track(key: int) -> void:
	if key == _want_key:
		return
	_want_key = key
	if _cache.has(key):
		_switch_to(key)
	elif not _tasks.has(key):
		_tasks[key] = WorkerThreadPool.add_task(_generate.bind(key), false, "music_%d" % key)


func _generate(key: int) -> void:
	var wav: AudioStreamWAV = Synth.build_track(key)
	_on_generated.call_deferred(key, wav)


func _on_generated(key: int, wav: AudioStreamWAV) -> void:
	if _tasks.has(key):
		WorkerThreadPool.wait_for_task_completion(_tasks[key])
		_tasks.erase(key)
	_cache[key] = wav
	if key == _want_key:
		_switch_to(key)


func _switch_to(key: int) -> void:
	if key == _playing_key:
		return
	var next: int = 1 - maxi(_active, 0) if _active >= 0 else 0
	var p: AudioStreamPlayer = _players[next]
	p.stream = _cache[key]
	p.volume_db = MIN_DB
	_levels[next] = 0.0
	p.play()
	_active = next
	_playing_key = key


# --- Довкілля -----------------------------------------------------------------------

func _ensure_ambient() -> void:
	if _ambient_ready:
		return
	_ambient_ready = true
	for kind: StringName in Synth.AMBIENT_KINDS:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.name = "Amb_%s" % kind
		p.bus = AudioManager.BUS_AMBIENT
		p.stream = Synth.build_ambient(kind)
		p.volume_db = MIN_DB
		add_child(p)
		_layers[kind] = p
		_layer_level[kind] = 0.0
		_layer_target[kind] = 0.0
	for kind: StringName in [&"chirp", &"croak", &"hoot", &"thunder"]:
		var list: Array = []
		for v: int in (3 if kind == &"chirp" else 1):
			list.append(Synth.build_event(kind, v))
		_events[kind] = list


func _apply_ambient_mix(biome: int, night: bool) -> void:
	var mix: Dictionary = {&"wind": 0.0, &"water": 0.0, &"leaves": 0.0, &"crickets": 0.0}
	_event_kinds = []
	match biome:
		WorldGen.Biome.FOREST:
			mix[&"leaves"] = 0.25 if night else 0.55
			mix[&"crickets"] = 0.5 if night else 0.0
			_event_kinds = _kinds(&"hoot" if night else &"chirp")
		WorldGen.Biome.DESERT:
			mix[&"wind"] = 0.35 if night else 0.6
			mix[&"crickets"] = 0.3 if night else 0.0
		WorldGen.Biome.LAKE:
			mix[&"water"] = 0.5 if night else 0.6
			mix[&"leaves"] = 0.0 if night else 0.2
			mix[&"crickets"] = 0.4 if night else 0.0
			_event_kinds = _kinds(&"croak" if night else &"chirp")
		_:
			mix[&"wind"] = 0.9 if night else 0.8
	for kind: StringName in mix:
		_layer_target[kind] = mix[kind]


func _kinds(kind: StringName) -> Array[StringName]:
	var out: Array[StringName] = [kind]
	return out


func _process(delta: float) -> void:
	_duck = move_toward(_duck, _duck_target, delta / DUCK_FADE)
	for i: int in 2:
		var target: float = MUSIC_GAIN if i == _active else 0.0
		_levels[i] = move_toward(_levels[i], target, delta / MUSIC_FADE * MUSIC_GAIN)
		var p: AudioStreamPlayer = _players[i]
		var v: float = _levels[i] * _duck
		p.volume_db = linear_to_db(v) if v > 0.001 else MIN_DB
		if _levels[i] <= 0.0 and i != _active and p.playing:
			p.stop()
	for kind: StringName in _layers:
		var lp: AudioStreamPlayer = _layers[kind]
		var tgt: float = _layer_target[kind]
		if kind == &"rain":
			tgt = _rain_level * 0.85
		elif kind != &"crickets":
			tgt *= 1.0 - 0.5 * _rain_level
		var lvl: float = move_toward(_layer_level[kind], tgt, delta / LAYER_FADE)
		_layer_level[kind] = lvl
		var lv: float = lvl * _duck
		if lv > 0.002:
			lp.volume_db = linear_to_db(lv)
			if not lp.playing:
				lp.play()
		elif lp.playing:
			lp.stop()
	_event_timer -= delta
	if _event_timer <= 0.0:
		_event_timer = _rng.randf_range(4.0, 10.0)
		_play_random_event()


func _play_random_event() -> void:
	if _event_kinds.is_empty() or _duck < 0.9 or _event_player.playing or _rain_level > 0.3:
		return
	var kind: StringName = _event_kinds[_rng.randi() % _event_kinds.size()]
	var list: Array = _events.get(kind, [])
	if list.is_empty():
		return
	_event_player.stream = list[_rng.randi() % list.size()]
	_event_player.pitch_scale = _rng.randf_range(0.9, 1.25) if kind == &"chirp" else _rng.randf_range(0.92, 1.08)
	_event_player.play()
