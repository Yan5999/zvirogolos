class_name SpeciesData
extends Resource
## Описание вида животного. Экземпляры лежат в resources/species/*.tres —
## их можно править в инспекторе. Внешний вид пока процедурный (см. animal.gd);
## для настоящего арта заполните `sprite` — тогда он заменит процедурное тело.

enum Hideout { BUSH, ROCK, BURROW, SNOWDRIFT, REEDS }
enum Ears { NONE, POINTY, ROUND, LONG }
enum Feature { NONE, HORN, BEAK, CAP, SPIKES, ANTLERS, HUMP, SHELL, TUSKS }
enum Tail { NONE, SHORT, BUSHY, THIN, FLAT }

@export var id: StringName
@export var display_name: String = ""
## Латинська (наукова) назва виду.
@export var latin_name: String = ""
@export_multiline var description: String = ""
@export_enum("Ліс", "Пустеля", "Озеро", "Сніги") var biome: int = 0
@export var hideout: Hideout = Hideout.BUSH

@export_group("Зовнішній вигляд")
@export var sprite: Texture2D
@export var body_color: Color = Color.SADDLE_BROWN
@export var belly_color: Color = Color.WHEAT
@export var accent_color: Color = Color.DARK_RED
@export var body_radii: Vector2 = Vector2(12, 9)
## Колір голови; прозорий (alpha = 0) — як у тіла.
@export var head_color: Color = Color(0, 0, 0, 0)
@export var ears: Ears = Ears.ROUND
@export_range(0.3, 2.5, 0.05) var ear_scale: float = 1.0
@export var ear_tufts: bool = false
@export var face_mask: bool = false
@export var feature: Feature = Feature.NONE
@export var tail: Tail = Tail.NONE
@export_range(0.0, 3.0, 0.05) var neck_length: float = 0.0
@export_range(0.4, 2.0, 0.05) var head_scale: float = 1.0

@export_group("Голос")
## Базовый питч голоса этого вида (1.0 — без изменений).
@export_range(0.5, 2.0, 0.01) var base_pitch: float = 1.0
## Случайный разброс питча ± при каждом проигрывании.
@export_range(0.0, 0.3, 0.01) var pitch_variance: float = 0.06

@export_group("Поведінка")
@export var wanders: bool = true
@export var wander_speed: float = 28.0
@export var wander_radius: float = 56.0


func random_pitch() -> float:
	return base_pitch * randf_range(1.0 - pitch_variance, 1.0 + pitch_variance)
