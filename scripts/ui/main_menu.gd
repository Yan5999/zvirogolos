extends Control
## Главное меню: играть/продолжить, настройки, сброс прогресса, выход.

const WORLD_SCENE: String = "res://scenes/world/world.tscn"

@onready var play_button: Button = %PlayButton
@onready var settings_button: Button = %SettingsButton
@onready var reset_button: Button = %ResetButton
@onready var quit_button: Button = %QuitButton
@onready var progress_label: Label = %ProgressLabel
@onready var settings: SettingsPanel = %SettingsPanel
@onready var reset_dialog: ConfirmationDialog = %ResetDialog
@onready var critters: Control = %Critters


func _ready() -> void:
	play_button.pressed.connect(_on_play)
	settings_button.pressed.connect(settings.open)
	settings.closed.connect(settings_button.grab_focus)
	reset_button.pressed.connect(reset_dialog.popup_centered)
	reset_dialog.confirmed.connect(_on_reset_confirmed)
	quit_button.pressed.connect(_on_quit)
	quit_button.visible = not OS.has_feature("web")
	critters.draw.connect(_on_critters_draw)
	AudioManager.attach_click_sounds($Center)
	_refresh()
	play_button.grab_focus()


func _refresh() -> void:
	var found: int = GameState.found_count()
	progress_label.text = "Знайдено звірів: %d з %d" % [found, GameState.total()]
	play_button.text = "Продовжити" if found > 0 else "Грати"
	reset_button.disabled = found == 0
	critters.queue_redraw()


func _on_play() -> void:
	get_tree().change_scene_to_file(WORLD_SCENE)


func _on_reset_confirmed() -> void:
	GameState.reset_progress()
	AudioManager.play_ui(&"delete")
	_refresh()
	play_button.grab_focus()


func _on_quit() -> void:
	GameState.save()
	AudioManager.stop_all()
	get_tree().quit()


## Декоративный ряд силуэтов видов внизу меню (открытые — цветные, остальные — тени).
func _on_critters_draw() -> void:
	var list: Array[SpeciesData] = GameState.SPECIES_DB.species
	var known: Dictionary[String, bool] = {}
	for rec: Dictionary in GameState.records.values():
		known[String(rec.get("species", ""))] = true
	var per_row: int = ceili(list.size() / 2.0)
	var step: float = critters.size.x / float(per_row + 1)
	for i: int in list.size():
		var s: SpeciesData = list[i]
		var row: int = i / per_row
		var c: Vector2 = Vector2(step * (i % per_row + 1), critters.size.y * (0.38 + 0.42 * row))
		var seen: bool = known.has(String(s.id))
		var col: Color = s.body_color if seen else Color(0, 0, 0, 0.35)
		var k: float = 0.9
		DrawUtil.draw_ellipse(critters, c, s.body_radii * k, col)
		critters.draw_circle(c + Vector2(s.body_radii.x * 0.75, -s.body_radii.y * 0.8), maxf(5.0, s.body_radii.y * 0.65), col)
		if seen:
			critters.draw_circle(c + Vector2(s.body_radii.x * 0.95, -s.body_radii.y * 0.9), 2.0, Color.WHITE)
