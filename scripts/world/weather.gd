class_name Weather
extends Node
## Погода: випадкові дощі (з грозою) у лісі й біля озера. Дощ — екранні частинки, світ темнішає,
## у MusicDirector вмикається шар дощу, блискавка — спалах і грім із затримкою.

const CLEAR_MIN: float = 100.0
const CLEAR_MAX: float = 260.0
const RAIN_MIN: float = 45.0
const RAIN_MAX: float = 100.0
const FADE_TIME: float = 3.0

var raining: bool = false
var intensity: float = 0.0
var rain: CPUParticles2D
var flash: ColorRect

var _timer: float = 0.0
var _thunder_timer: float = 15.0
var _was_wet: bool = false
var _player: Player
var _day_night: DayNight
var _hud: Hud
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func setup(player: Player, day_night: DayNight, hud: Hud) -> void:
	_player = player
	_day_night = day_night
	_hud = hud
	_rng.randomize()
	_timer = _rng.randf_range(CLEAR_MIN * 0.5, CLEAR_MAX)
	_build_visuals()


func _exit_tree() -> void:
	if AudioManager and AudioManager.music:
		AudioManager.music.set_rain(0.0)


func _process(delta: float) -> void:
	tick(delta)


## Крок симуляції (окремо від _process, щоб тестувати з великою delta).
func tick(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		raining = not raining
		_timer = _rng.randf_range(RAIN_MIN, RAIN_MAX) if raining else _rng.randf_range(CLEAR_MIN, CLEAR_MAX)
	var biome: int = _player.current_biome()
	var wet: bool = raining and (biome == WorldGen.Biome.FOREST or biome == WorldGen.Biome.LAKE)
	intensity = move_toward(intensity, 1.0 if wet else 0.0, delta / FADE_TIME)
	rain.emitting = intensity > 0.02
	rain.modulate.a = intensity
	_day_night.weather_dim = intensity
	AudioManager.music.set_rain(intensity)
	if wet and not _was_wet:
		_hud.show_toast("Починається дощ", 2.5)
	_was_wet = wet
	if intensity > 0.8:
		_thunder_timer -= delta
		if _thunder_timer <= 0.0:
			_thunder_timer = _rng.randf_range(14.0, 32.0)
			lightning()


func force_rain(on: bool) -> void:
	raining = on
	_timer = 9999.0


## Спалах (подвійний) і грім із затримкою.
func lightning() -> void:
	var tw: Tween = create_tween()
	tw.tween_property(flash, "color:a", 0.55, 0.05)
	tw.tween_property(flash, "color:a", 0.1, 0.08)
	tw.tween_property(flash, "color:a", 0.4, 0.05)
	tw.tween_property(flash, "color:a", 0.0, 0.4)
	get_tree().create_timer(_rng.randf_range(0.5, 1.6)).timeout.connect(AudioManager.music.play_thunder)


func _build_visuals() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "WeatherLayer"
	layer.layer = 0
	add_child(layer)
	var img: Image = Image.create(2, 18, false, Image.FORMAT_RGBA8)
	for y: int in 18:
		var a: float = float(y) / 17.0
		for x: int in 2:
			img.set_pixel(x, y, Color(0.8, 0.88, 1.0, a * 0.75))
	var size: Vector2 = get_viewport().get_visible_rect().size
	rain = CPUParticles2D.new()
	rain.name = "Rain"
	rain.texture = ImageTexture.create_from_image(img)
	rain.amount = 220
	rain.lifetime = (size.y + 60.0) / 820.0
	rain.preprocess = rain.lifetime
	rain.emitting = false
	rain.position = Vector2(size.x * 0.5, -30.0)
	rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	rain.emission_rect_extents = Vector2(size.x * 0.5 + 120.0, 1.0)
	rain.direction = Vector2(-0.22, 1.0)
	rain.spread = 2.0
	rain.initial_velocity_min = 720.0
	rain.initial_velocity_max = 900.0
	rain.gravity = Vector2.ZERO
	rain.particle_flag_align_y = true
	rain.modulate.a = 0.0
	layer.add_child(rain)
	flash = ColorRect.new()
	flash.name = "Flash"
	flash.color = Color(0.92, 0.95, 1.0, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(flash)
