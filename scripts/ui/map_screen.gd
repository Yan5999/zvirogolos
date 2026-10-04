class_name MapScreen
extends CanvasLayer
## Повноекранна мапа (M / Back): світ, знайдені звірі з іменами, гравець, прогрес по біомах.

@onready var map_view: MapView = %MapView
@onready var stats_label: Label = %StatsLabel
@onready var close_button: Button = %CloseButton


func _ready() -> void:
	visible = false
	close_button.pressed.connect(close)
	AudioManager.attach_click_sounds(close_button)


func is_open() -> bool:
	return visible


func open() -> void:
	_refresh_stats()
	visible = true
	get_tree().paused = true
	map_view.queue_redraw()
	AudioManager.play_ui(&"open")
	close_button.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false
	AudioManager.play_ui(&"close")


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"open_map") or event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		close()


func _refresh_stats() -> void:
	var totals: Array[int] = [0, 0, 0, 0]
	var found: Array[int] = [0, 0, 0, 0]
	for spot: Dictionary in GameState.spots:
		var b: int = spot["biome"]
		totals[b] += 1
		if GameState.is_discovered(spot["id"]):
			found[b] += 1
	var lines: PackedStringArray = PackedStringArray()
	for b: int in MapView.BIOME_NAMES.size():
		lines.append("%s: %d / %d" % [MapView.BIOME_NAMES[b], found[b], totals[b]])
	lines.append("")
	lines.append("Разом: %d / %d" % [GameState.found_count(), GameState.total()])
	stats_label.text = "\n".join(lines)
