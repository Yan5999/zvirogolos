class_name World
extends Node2D
## Сцена мира: строит тайлы из WorldGen, ставит игрока, связывает UI.

const MAIN_MENU_SCENE: String = "res://scenes/main_menu/main_menu.tscn"
const AUTOSAVE_INTERVAL: float = 15.0
const INTERACT_DISTANCE: float = 90.0
const ANIMAL_SCENE: PackedScene = preload("res://scenes/animal/animal.tscn")

@onready var ground: TileMapLayer = $Ground
@onready var decor_layer: TileMapLayer = $Decor
@onready var entities: Node2D = $Entities
@onready var player: Player = $Entities/Player
@onready var hud: Hud = $HUD
@onready var record_dialog: RecordDialog = $RecordDialog
@onready var zoo_ui: ZooUI = $ZooUI
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var map_screen: MapScreen = $MapScreen

var animals: Dictionary[String, Animal] = {}
var _autosave_timer: float = 0.0
var _hint_timer: float = 0.0
var _default_hint: String = ""
var _reopen_zoo: bool = false


func _ready() -> void:
	var gen: WorldGen = GameState.world_gen
	var tile_set: TileSet = TileSetBuilder.build()
	ground.tile_set = tile_set
	decor_layer.tile_set = tile_set
	decor_layer.collision_enabled = false
	_paint(gen)
	player.global_position = GameState.player_position
	player.set_camera_limits(gen.world_rect())
	_spawn_animals()
	GameState.progress_changed.connect(hud.set_progress)
	GameState.animal_updated.connect(_on_animal_updated)
	GameState.animal_forgotten.connect(_on_animal_forgotten)
	hud.set_progress(GameState.found_count(), GameState.total())
	record_dialog.closed.connect(_on_record_dialog_closed)
	zoo_ui.record_requested.connect(_on_zoo_record_requested)
	pause_menu.zoo_requested.connect(open_zoo)
	pause_menu.main_menu_requested.connect(go_to_menu)
	pause_menu.map_requested.connect(open_map)
	hud.minimap.player = player
	map_screen.map_view.player = player
	GameState.progress_changed.connect(_on_progress_changed)
	_default_hint = hud.hint_label.text


func _spawn_animals() -> void:
	for spot: Dictionary in GameState.spots:
		var id: String = spot["id"]
		var a: Animal = ANIMAL_SCENE.instantiate() as Animal
		a.name = "Animal_" + id
		entities.add_child(a)
		a.global_position = spot["position"]
		a.setup(id, GameState.get_species(spot["species"]), GameState.get_record(id), player)
		a.discovered.connect(_on_animal_discovered)
		a.reveal_finished.connect(_on_animal_reveal_finished)
		animals[id] = a


func _on_animal_discovered(a: Animal) -> void:
	GameState.discover(a.animal_id)
	hud.show_toast("Новий звір: %s!" % a.species.display_name)


func _on_animal_reveal_finished(a: Animal) -> void:
	AudioManager.play_ui(&"discover")
	open_record_dialog(a.animal_id, true)


func open_record_dialog(id: String, is_new: bool) -> void:
	_store_and_save()
	record_dialog.open(id, is_new)


func _on_zoo_record_requested(id: String) -> void:
	_reopen_zoo = true
	get_tree().paused = false
	open_record_dialog(id, false)


func open_map() -> void:
	_store_and_save()
	map_screen.open()


func open_zoo() -> void:
	_store_and_save()
	zoo_ui.open()


func _on_progress_changed(found: int, total: int) -> void:
	if found == total and total > 0:
		hud.show_toast("Усіх %d звірів знайдено! Зоопарк повний голосів." % total, 5.0)


func _on_record_dialog_closed(id: String, saved: bool) -> void:
	if _reopen_zoo:
		_reopen_zoo = false
		zoo_ui.open()
		return
	if saved:
		hud.show_toast("%s тепер живе у вашому зоопарку" % GameState.get_record(id).get("name", ""))


## Ближайшее открытое животное в радиусе взаимодействия.
func nearest_active_animal(max_dist: float = INTERACT_DISTANCE) -> Animal:
	var best: Animal = null
	var best_d: float = max_dist
	for a: Animal in animals.values():
		if not a.is_active():
			continue
		var d: float = a.creature_global_position().distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = a
	return best


func _on_animal_updated(id: String) -> void:
	if animals.has(id):
		animals[id].refresh(GameState.get_record(id))


func _on_animal_forgotten(id: String) -> void:
	if animals.has(id):
		animals[id].hide_again()


func _paint(gen: WorldGen) -> void:
	for y: int in WorldGen.HEIGHT:
		for x: int in WorldGen.WIDTH:
			var i: int = gen.index(x, y)
			var variants: Array = TileSetBuilder.TERRAIN_TILES[int(gen.terrain[i])]
			var v: Vector2i = variants[posmod(hash(Vector2i(x, y)), variants.size())]
			ground.set_cell(Vector2i(x, y), TileSetBuilder.SOURCE_ID, v)
			var d: int = gen.decor[i]
			if d != WorldGen.Decor.NONE:
				decor_layer.set_cell(Vector2i(x, y), TileSetBuilder.SOURCE_ID, TileSetBuilder.decor_tile(d))


func _process(delta: float) -> void:
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_INTERVAL:
		_autosave_timer = 0.0
		_store_and_save()
	_hint_timer -= delta
	if _hint_timer <= 0.0:
		_hint_timer = 0.2
		var near: Animal = nearest_active_animal()
		hud.set_hint(("E — ім'я та голос для «%s»" % near.display_name) if near else _default_hint)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact"):
		var near: Animal = nearest_active_animal()
		if near:
			get_viewport().set_input_as_handled()
			open_record_dialog(near.animal_id, false)
	elif event.is_action_pressed(&"open_map"):
		get_viewport().set_input_as_handled()
		open_map()
	elif event.is_action_pressed(&"open_zoo"):
		get_viewport().set_input_as_handled()
		open_zoo()
	elif event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		_store_and_save()
		pause_menu.open()


func go_to_menu() -> void:
	_store_and_save()
	AudioManager.stop_voices()
	AudioManager.stop_preview()
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _store_and_save() -> void:
	GameState.player_position = player.global_position
	for id: String in animals:
		var a: Animal = animals[id]
		if a.is_active():
			GameState.update_animal_position(id, a.creature_global_position())
	GameState.save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_node_ready():
		_store_and_save()
