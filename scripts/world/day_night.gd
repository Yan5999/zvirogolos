class_name DayNight
extends CanvasModulate
## Цикл дня і ночі: тонує світ за GameState.time_of_day і вмикає ліхтар гравця вночі.
## UI живе на CanvasLayer, тому не темніє.

const NIGHT: Color = Color(0.28, 0.32, 0.58)
const DAWN: Color = Color(0.95, 0.72, 0.66)
const DUSK: Color = Color(1.0, 0.7, 0.52)

var lantern: PointLight2D
var _gradient: Gradient = Gradient.new()


func _ready() -> void:
	_gradient.offsets = PackedFloat32Array([0.0, 0.2, 0.27, 0.35, 0.65, 0.73, 0.8, 1.0])
	_gradient.colors = PackedColorArray([NIGHT, NIGHT, DAWN, Color.WHITE, Color.WHITE, DUSK, NIGHT, NIGHT])
	_apply()


## Створює м'яке коло світла навколо вузла (ліхтар гравця).
func attach_lantern(target: Node2D) -> void:
	var g: Gradient = Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 256
	tex.height = 256
	lantern = PointLight2D.new()
	lantern.texture = tex
	lantern.texture_scale = 2.4
	lantern.color = Color(1.0, 0.85, 0.55)
	lantern.position = Vector2(0, -12)
	target.add_child(lantern)
	_apply()


func _process(delta: float) -> void:
	GameState.advance_time(delta)
	_apply()


func _apply() -> void:
	var t: float = GameState.time_of_day
	color = _gradient.sample(t)
	if lantern:
		# Плавно: повна сила вночі, нуль удень.
		var night_k: float = 1.0 - clampf((color.v - NIGHT.v) / (1.0 - NIGHT.v), 0.0, 1.0)
		lantern.energy = night_k * 0.9
		lantern.visible = night_k > 0.02


## Текст для HUD: «День 14:20» / «Ніч 02:10».
static func clock_text() -> String:
	var minutes: int = int(GameState.time_of_day * 24.0 * 60.0)
	return "%s %02d:%02d" % ["Ніч" if GameState.is_night() else "День", minutes / 60, minutes % 60]
