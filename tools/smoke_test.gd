extends Node
## Headless-проверки: godot --headless --path . res://tools/smoke_test.tscn
## Печатает PASS/FAIL по пунктам и завершает процесс с кодом ошибки при сбое.

const WORLD_SCENE: PackedScene = preload("res://scenes/world/world.tscn")

var _failures: int = 0


func _ready() -> void:
	await _run()
	AudioManager.stop_all()
	await get_tree().create_timer(0.3).timeout
	print("SMOKE: %s (%d failures)" % ["OK" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS ", label)
	else:
		_failures += 1
		print("  FAIL ", label)


func frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _run() -> void:
	GameState.reset_progress()
	var t0: int = Time.get_ticks_msec()
	var world: World = WORLD_SCENE.instantiate() as World
	add_child(world)
	await frames(2)
	print("  world built in %d ms" % (Time.get_ticks_msec() - t0))
	check(world.ground.get_used_cells().size() == WorldGen.WIDTH * WorldGen.HEIGHT, "ground fully painted")
	var start: Vector2 = world.player.global_position
	Input.action_press(&"move_right")
	await frames(30)
	Input.action_release(&"move_right")
	check(world.player.global_position.x > start.x + 30.0, "player moves right")
	# Вода непроходима: телепорт у края и попытка уйти за карту.
	world.player.global_position = Vector2(WorldGen.TILE_SIZE * 5.5, WorldGen.TILE_SIZE * 64.5)
	Input.action_press(&"move_left")
	await frames(90)
	Input.action_release(&"move_left")
	check(world.player.global_position.x > WorldGen.TILE_SIZE * 3.0, "water blocks player")
	await _stage_checks(world)
	world.queue_free()
	await frames(2)


## Расширяется на следующих этапах.
func _stage_checks(world: World) -> void:
	GameState.reset_progress()
	check(GameState.total() == 30, "30 spots generated (got %d)" % GameState.total())
	check(world.animals.size() == GameState.total(), "animal per spot")
	var biomes: Dictionary = {}
	for spot: Dictionary in GameState.spots:
		biomes[spot["biome"]] = true
		check(GameState.world_gen.is_walkable_pos(spot["position"]), "spot %s on land" % spot["id"])
	check(biomes.size() == 4, "spots in all 4 biomes")
	var uniq: Dictionary = {}
	for spot: Dictionary in GameState.spots:
		uniq[spot["species"]] = true
		check(GameState.species_of(spot["id"]).biome == int(spot["biome"]), "species %s fits biome" % spot["species"])
	check(uniq.size() == 30, "30 different species (got %d)" % uniq.size())
	var first: Dictionary = GameState.spots[0]
	var a: Animal = world.animals[first["id"]]
	check(a.state == Animal.State.HIDDEN, "animal starts hidden")
	world.player.global_position = a.global_position + Vector2(0, 30)
	await frames(10)
	check(a.state != Animal.State.HIDDEN, "animal reveals on approach")
	check(GameState.is_discovered(first["id"]), "discovery recorded")
	await get_tree().create_timer(1.2).timeout
	check(a.state == Animal.State.ACTIVE, "animal active after reveal tween")
	check(world.record_dialog.is_open(), "record dialog auto-opens after reveal")
	world.record_dialog.close(false)
	await frames(1)
	check(GameState.found_count() == 1, "progress 1")
	GameState.rename(first["id"], "  Тестик  ")
	check(a.display_name == "Тестик", "rename propagates to label")
	var saved: Dictionary = SaveManager.load_game()
	check((saved.get("animals", []) as Array).size() == 1, "save.json contains record")
	await _stage3_checks(world, a)


## Тестовый сигнал: стерео 16 бит, 0.5 с тишины + 1 с тона -20 dB + 0.7 с тишины.
func make_test_wav() -> AudioStreamWAV:
	var rate: int = 44100
	var frames: int = int(2.2 * rate)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(frames * 4)
	for f: int in frames:
		var t: float = float(f) / rate
		var v: float = 0.0
		if t >= 0.5 and t < 1.5:
			v = sin(TAU * 440.0 * t) * 0.1
		var iv: int = int(v * 32767.0)
		bytes.encode_s16(f * 4, iv)
		bytes.encode_s16(f * 4 + 2, iv)
	var w: AudioStreamWAV = AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.stereo = true
	w.mix_rate = rate
	w.data = bytes
	return w


func _stage3_checks(world: World, a: Animal) -> void:
	var t0: int = Time.get_ticks_msec()
	var res: VoiceProcessing.Result = VoiceProcessing.process(make_test_wav())
	print("  processing took %d ms" % (Time.get_ticks_msec() - t0))
	check(res.ok, "processing ok")
	check(res.duration > 1.0 and res.duration < 1.2, "silence trimmed (%.2f s)" % res.duration)
	var mono: PackedFloat32Array = VoiceProcessing.decode_mono(res.stream)
	var pk: float = 0.0
	for v: float in mono:
		pk = maxf(pk, absf(v))
	check(absf(linear_to_db(pk) - VoiceProcessing.TARGET_PEAK_DB) < 0.5, "normalized to -1 dBFS (%.2f)" % linear_to_db(pk))
	check(not res.stream.stereo, "mono output")
	var silent: VoiceProcessing.Result = VoiceProcessing.process(VoiceProcessing.encode_wav(PackedFloat32Array([0.0, 0.0001, 0.0]), 44100))
	check(silent.silent, "silence detected")
	# Длинный тон > 5 с обрезается.
	var long_s: PackedFloat32Array = PackedFloat32Array()
	long_s.resize(44100 * 7)
	for i: int in long_s.size():
		long_s[i] = sin(float(i) * 0.05) * 0.5
	var long_res: VoiceProcessing.Result = VoiceProcessing.process(VoiceProcessing.encode_wav(long_s, 44100))
	check(long_res.duration <= VoiceProcessing.MAX_SECONDS + 0.01, "capped to 5 s")

	# Диалог: загрузка из файла и сохранение.
	var id: String = a.animal_id
	var test_path: String = "user://smoke_input.wav"
	make_test_wav().save_to_wav(test_path)
	world.open_record_dialog(id, false)
	await frames(2)
	check(world.record_dialog.is_open() and get_tree().paused, "dialog opens and pauses")
	world.record_dialog.name_edit.text = "Гарчизавр"
	world.record_dialog._on_file_selected(ProjectSettings.globalize_path(test_path))
	world.record_dialog._on_save_pressed()
	await frames(2)
	check(not world.record_dialog.is_open() and not get_tree().paused, "dialog closes and unpauses")
	check(GameState.get_record(id).get("name") == "Гарчизавр", "name saved")
	check(FileAccess.file_exists(SaveManager.VOICES_DIR + "%s.wav" % id), "wav written to user://voices")
	var loaded: AudioStreamWAV = SaveManager.load_voice("%s.wav" % id)
	check(loaded != null and absf(loaded.get_length() - res.duration) < 0.05, "wav reloads with same length")
	await _stage4_checks(world, a)


func _stage4_checks(world: World, a: Animal) -> void:
	AudioManager.stop_voices()
	world.player.global_position = a.creature_global_position() + Vector2(0, 400)
	await frames(5)
	a.reset_voice_cooldown()
	world.player.global_position = a.creature_global_position() + Vector2(0, 60)
	await frames(5)
	check(AudioManager.active_voice_count() == 1, "voice plays when player comes near")
	check(a.voice_cooldown_left() > 0.0, "cooldown started")
	check(not a.try_play_voice(), "cooldown blocks spam")
	# Лимит одновременных голосов.
	AudioManager.stop_voices()
	var stream: AudioStreamWAV = GameState.get_voice(a.animal_id)
	var ok_count: int = 0
	var dummies: Array[Node2D] = []
	for i: int in 7:
		var n: Node2D = Node2D.new()
		world.add_child(n)
		dummies.append(n)
		if AudioManager.play_voice_at(stream, n, 1.0):
			ok_count += 1
	check(ok_count == AudioManager.MAX_VOICES, "polyphony limited to %d (got %d)" % [AudioManager.MAX_VOICES, ok_count])
	for n: Node2D in dummies:
		n.queue_free()
	AudioManager.stop_voices()
	var sp: SpeciesData = a.species
	var in_range: bool = true
	for i: int in 50:
		var p: float = sp.random_pitch()
		in_range = in_range and p >= sp.base_pitch * (1.0 - sp.pitch_variance) - 0.001 and p <= sp.base_pitch * (1.0 + sp.pitch_variance) + 0.001
	check(in_range, "pitch varies within species range")
	await _stage5_checks(world, a)


func _stage5_checks(world: World, a: Animal) -> void:
	# Открываем ещё одного зверя для списка.
	var second: Animal = world.animals[GameState.spots[5]["id"]]
	world.player.global_position = second.global_position + Vector2(0, 20)
	await frames(5)
	await get_tree().create_timer(1.0).timeout
	world.record_dialog.close(false)
	await frames(1)
	check(GameState.found_count() == 2, "second animal discovered")
	world.open_zoo()
	await frames(2)
	check(world.zoo_ui.is_open() and get_tree().paused, "zoo opens and pauses")
	var visible_rows: int = 0
	for row: ZooEntry in world.zoo_ui._rows:
		if row.visible:
			visible_rows += 1
	check(visible_rows == 2, "zoo lists 2 animals")
	check(world.zoo_ui.progress_label.text == "Знайдено: 2 / 30", "zoo progress label")
	var row0: ZooEntry = world.zoo_ui._rows[0]
	check(row0.animal_id == a.animal_id and not row0.play_button.disabled, "first row has voice")
	row0.name_edit.text = "Нове ім'я"
	row0._commit_name()
	check(a.display_name == "Нове ім'я", "rename from zoo")
	row0.play_button.pressed.emit()
	await frames(1)
	check(AudioManager.is_preview_playing(), "listen from zoo")
	# Перезаписать -> открывается диалог, после закрытия зоопарк возвращается.
	row0.record_button.pressed.emit()
	await frames(2)
	check(world.record_dialog.is_open(), "re-record opens dialog")
	world.record_dialog.close(false)
	await frames(2)
	check(world.zoo_ui.is_open(), "zoo reopens after dialog")
	# Удаление.
	world.zoo_ui._on_delete(second.animal_id)
	world.zoo_ui.confirm_dialog.hide()
	world.zoo_ui._on_delete_confirmed()
	await frames(2)
	check(GameState.found_count() == 1 and second.state == Animal.State.HIDDEN, "delete returns animal to hideout")
	world.zoo_ui.close()
	await frames(1)
	check(not get_tree().paused, "zoo closes and unpauses")
	# Персистентность прогресса: перечитываем сейв.
	var data: Dictionary = SaveManager.load_game()
	check((data.get("animals", []) as Array).size() == 1, "progress persisted")
	await _stage6_checks(world)


func _stage6_checks(world: World) -> void:
	world.pause_menu.open()
	await frames(1)
	check(get_tree().paused, "pause menu pauses")
	world.pause_menu.settings.open()
	world.pause_menu.settings.voices_slider.value = 0.5
	check(absf(AudioManager.get_bus_volume(AudioManager.BUS_VOICES) - 0.5) < 0.01, "voices volume via bus")
	check(absf(float(SaveManager.get_setting("audio", "Voices", 0.0)) - 0.5) < 0.01, "volume persisted")
	world.pause_menu.settings.voices_slider.value = 0.8
	world.pause_menu.settings.close()
	world.pause_menu.close()
	await frames(1)
	check(not get_tree().paused, "pause menu closes")
	world.player.global_position = GameState.world_gen.cell_center(Vector2i(64, 12))
	await frames(40)
	check(world.player.weather.emitting, "snow weather in snow biome")
	check(not SteamManager.enabled, "steam disabled without GodotSteam")
	var img: Image = GameState.world_gen.build_map_image()
	check(img.get_width() == WorldGen.WIDTH and img.get_height() == WorldGen.HEIGHT, "map image size")
	check(world.hud.minimap.player == world.player, "minimap tracks player")
	world.record_dialog.close(false)
	await frames(1)
	var ev: InputEventAction = InputEventAction.new()
	ev.action = &"open_map"
	ev.pressed = true
	Input.parse_input_event(ev)
	await frames(2)
	check(world.map_screen.is_open() and get_tree().paused, "M opens map and pauses")
	check(world.map_screen.stats_label.text.contains("Разом: %d / 30" % GameState.found_count()), "map biome stats")
	world.map_screen.close()
	await frames(1)
	check(not get_tree().paused, "map closes")
	# Стабильность: 600 кадров бега по карте без ошибок.
	var t0: int = Time.get_ticks_msec()
	world.player.global_position = GameState.world_gen.start_position()
	Input.action_press(&"run")
	Input.action_press(&"move_left")
	await frames(300)
	Input.action_release(&"move_left")
	Input.action_press(&"move_down")
	await frames(300)
	Input.action_release(&"move_down")
	Input.action_release(&"run")
	print("  600 physics frames in %d ms (headless)" % (Time.get_ticks_msec() - t0))
