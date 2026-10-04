class_name Hud
extends CanvasLayer
## HUD: счётчик найденных, подсказки, всплывающие сообщения.

@onready var progress_label: Label = %ProgressLabel
@onready var hint_label: Label = %HintLabel
@onready var toast_label: Label = %ToastLabel
@onready var minimap: MapView = %Minimap

var _toast_tween: Tween


func _ready() -> void:
	toast_label.modulate.a = 0.0


func set_progress(found: int, total: int) -> void:
	progress_label.text = "Знайдено: %d / %d" % [found, total]


func set_hint(text: String) -> void:
	hint_label.text = text


func show_toast(text: String, duration: float = 2.5) -> void:
	toast_label.text = text
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast_label, "modulate:a", 1.0, 0.2)
	_toast_tween.tween_interval(duration)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.5)
