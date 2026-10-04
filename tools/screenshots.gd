extends Node
## Снимки экрана для визуальной проверки (нужен дисплей/Xvfb):
## SHOT_DIR=/tmp/shots/ godot --path . --rendering-method gl_compatibility res://tools/screenshots.tscn

const MENU: PackedScene = preload("res://scenes/main_menu/main_menu.tscn")
const WORLD: PackedScene = preload("res://scenes/world/world.tscn")

var _dir: String = ""


func _ready() -> void:
	_dir = OS.get_environment("SHOT_DIR")
	if _dir.is_empty():
		_dir = "user://shots/"
	DirAccess.make_dir_recursive_absolute(_dir)
	await _frames(5)
	var menu: Node = MENU.instantiate()
	add_child(menu)
	await _frames(15)
	await _shot("01_menu")
	menu.queue_free()
	GameState.reset_progress()
	var world: World = WORLD.instantiate() as World
	add_child(world)
	await _frames(30)
	await _shot("02_start")
	var forest: Dictionary = _spot_in_biome(WorldGen.Biome.FOREST)
	world.player.global_position = forest["position"] + Vector2(90, 70)
	await _frames(30)
	await _shot("03_hidden")
	world.player.global_position = forest["position"] + Vector2(10, 30)
	await get_tree().create_timer(1.3).timeout
	await _shot("04_dialog")
	world.record_dialog.name_edit.text = "Шурхотик"
	world.record_dialog._on_save_pressed()
	world.player.global_position = forest["position"] + Vector2(-40, 60)
	await _frames(30)
	await _shot("05_named")
	for b: int in [WorldGen.Biome.DESERT, WorldGen.Biome.LAKE, WorldGen.Biome.SNOW]:
		var s: Dictionary = _spot_in_biome(b)
		world.player.global_position = s["position"] + Vector2(0, 25)
		await get_tree().create_timer(1.3).timeout
		world.record_dialog.close(false)
		await _frames(40)
		await _shot("06_biome_%d" % b)
	world.open_zoo()
	await _frames(10)
	await _shot("07_zoo")
	world.zoo_ui.close()
	world.open_map()
	await _frames(5)
	await _shot("09_map")
	world.map_screen.close()
	await _gallery(world)
	world.pause_menu.open()
	world.pause_menu.settings.open()
	await _frames(5)
	await _shot("08_settings")
	AudioManager.stop_all()
	get_tree().quit()


## Усі 30 видів у ряд біля гравця — для перевірки малювання.
func _gallery(world: World) -> void:
	var scene: PackedScene = preload("res://scenes/animal/animal.tscn")
	var base: Vector2 = GameState.world_gen.start_position() + Vector2(-260, -130)
	world.player.global_position = GameState.world_gen.start_position() + Vector2(0, 200)
	var made: Array[Animal] = []
	for i: int in GameState.SPECIES_DB.species.size():
		var a: Animal = scene.instantiate() as Animal
		world.entities.add_child(a)
		a.global_position = base + Vector2((i % 10) * 58, (i / 10) * 70)
		var sp: SpeciesData = GameState.SPECIES_DB.species[i]
		a.setup("gallery_%d" % i, sp, {"id": "x", "name": sp.display_name.split(" ")[0], "position": [a.global_position.x, a.global_position.y]}, world.player)
		a.creature.position = Vector2.ZERO
		a.hideout.visible = false
		a.discover_area.monitoring = false
		made.append(a)
	world.player.global_position = base + Vector2(260, 130)
	await _frames(20)
	await _shot("10_gallery")
	for a: Animal in made:
		a.queue_free()


func _spot_in_biome(b: int) -> Dictionary:
	for s: Dictionary in GameState.spots:
		if int(s["biome"]) == b:
			return s
	return GameState.spots[0]


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_dir + shot_name + ".png")
