class_name Player
extends CharacterBody2D
## Игрок: top-down движение с ускорением/трением, бег, процедурная фигурка.

@export var walk_speed: float = 170.0
@export var run_speed: float = 290.0
@export var acceleration: float = 1500.0
@export var friction: float = 1900.0

var input_enabled: bool = true
var _facing: float = 1.0
var _bob_time: float = 0.0
var _biome_timer: float = 0.0
var _biome: int = -1
var _step_dist: float = 0.0
var fireflies: CPUParticles2D

@onready var visual: Node2D = $Visual
@onready var camera: Camera2D = $Camera2D
@onready var dust: CPUParticles2D = $Dust
@onready var weather: CPUParticles2D = $Weather


func _ready() -> void:
	visual.draw.connect(_on_visual_draw)
	visual.queue_redraw()
	queue_redraw()
	_make_fireflies()
	GameState.night_changed.connect(func(_n: bool) -> void: _refresh_fireflies())


func _physics_process(delta: float) -> void:
	var dir: Vector2 = Vector2.ZERO
	if input_enabled:
		dir = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var target_speed: float = run_speed if Input.is_action_pressed(&"run") else walk_speed
	if dir != Vector2.ZERO:
		velocity = velocity.move_toward(dir * target_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	move_and_slide()
	_animate(delta)
	var running: bool = velocity.length() > walk_speed * 1.05
	if velocity.length() > 40.0:
		_step_dist += velocity.length() * delta
		if _step_dist >= (AudioManager.STRIDE_RUN if running else AudioManager.STRIDE_WALK):
			_step_dist = 0.0
			AudioManager.play_step(_biome)
	else:
		_step_dist = AudioManager.STRIDE_WALK * 0.7
	if dust.emitting != running:
		dust.emitting = running
	_biome_timer -= delta
	if _biome_timer <= 0.0:
		_biome_timer = 0.5
		_update_weather()


## Атмосферные частицы по биому: снег в снегах, листья в лесу.
func _update_weather() -> void:
	var b: int = GameState.world_gen.biome_at(global_position)
	if b == _biome:
		return
	_biome = b
	AudioManager.set_biome(b)
	_refresh_fireflies()
	# Вітер у пустелі дме вбік, сніг і листя падають згори.
	weather.direction = Vector2(1.0, 0.15) if b == WorldGen.Biome.DESERT else Vector2(0.25, 1.0)
	weather.initial_velocity_min = 140.0 if b == WorldGen.Biome.DESERT else 40.0
	weather.initial_velocity_max = 220.0 if b == WorldGen.Biome.DESERT else 70.0
	match b:
		WorldGen.Biome.SNOW:
			weather.color = Color(0.72, 0.84, 0.97)
			weather.emitting = true
		WorldGen.Biome.FOREST:
			weather.color = Color(0.85, 0.6, 0.25)
			weather.emitting = true
		WorldGen.Biome.DESERT:
			weather.color = Color(0.93, 0.8, 0.55, 0.6)
			weather.emitting = true
		_:
			weather.emitting = false


func current_biome() -> int:
	return _biome


func is_moving() -> bool:
	return velocity.length() > 40.0


func set_camera_limits(rect: Rect2) -> void:
	camera.limit_left = int(rect.position.x)
	camera.limit_top = int(rect.position.y)
	camera.limit_right = int(rect.end.x)
	camera.limit_bottom = int(rect.end.y)
	camera.reset_smoothing()


func _animate(delta: float) -> void:
	if absf(velocity.x) > 5.0:
		var f: float = signf(velocity.x)
		if f != _facing:
			_facing = f
			visual.scale.x = _facing
	var speed: float = velocity.length()
	if speed > 10.0:
		_bob_time += delta * (8.0 + speed * 0.03)
		visual.position.y = -absf(sin(_bob_time)) * 3.0
		visual.rotation = sin(_bob_time) * 0.07
	else:
		visual.position.y = lerpf(visual.position.y, 0.0, minf(1.0, 12.0 * delta))
		visual.rotation = lerpf(visual.rotation, 0.0, minf(1.0, 12.0 * delta))


func _draw() -> void:
	DrawUtil.draw_ellipse(self, Vector2(0, 2), Vector2(10, 4), Color(0, 0, 0, 0.25))


func _on_visual_draw() -> void:
	# Плейсхолдер: исследователь в панаме. Замените Visual на Sprite2D/AnimatedSprite2D.
	visual.draw_rect(Rect2(-5, -6, 4, 7), Color("3a3a4a"))
	visual.draw_rect(Rect2(1, -6, 4, 7), Color("3a3a4a"))
	visual.draw_rect(Rect2(-10, -19, 5, 9), Color("8b5a2b"))
	DrawUtil.draw_ellipse(visual, Vector2(0, -13), Vector2(7, 8), Color("e67e22"))
	visual.draw_circle(Vector2(0, -25), 6.5, Color("f5cba7"))
	visual.draw_circle(Vector2(3, -25.5), 1.2, Color("2c2c2c"))
	DrawUtil.draw_ellipse(visual, Vector2(0, -29), Vector2(10, 2.5), Color("8f8a5a"))
	DrawUtil.draw_ellipse(visual, Vector2(0, -31), Vector2(6, 4), Color("a39e6a"))


## Світляки: екранний шар (CanvasLayer не темніє від CanvasModulate), лише вночі в лісі та біля озера.
func _make_fireflies() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "FirefliesLayer"
	layer.layer = 0
	add_child(layer)
	var g: Gradient = Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 32
	tex.height = 32
	var life: Gradient = Gradient.new()
	life.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	life.colors = PackedColorArray([Color(1, 0.95, 0.4, 0), Color(1, 0.95, 0.4, 1), Color(0.9, 1, 0.5, 1), Color(0.9, 1, 0.5, 0)])
	var mat: CanvasItemMaterial = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	fireflies = CPUParticles2D.new()
	fireflies.name = "Fireflies"
	fireflies.texture = tex
	fireflies.material = mat
	fireflies.amount = 36
	fireflies.lifetime = 7.0
	fireflies.preprocess = 7.0
	fireflies.emitting = false
	fireflies.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	var size: Vector2 = get_viewport_rect().size
	fireflies.position = size * 0.5
	fireflies.emission_rect_extents = size * 0.5
	fireflies.direction = Vector2(0, -1)
	fireflies.spread = 180.0
	fireflies.initial_velocity_min = 6.0
	fireflies.initial_velocity_max = 16.0
	fireflies.gravity = Vector2.ZERO
	fireflies.scale_amount_min = 0.25
	fireflies.scale_amount_max = 0.5
	fireflies.color_ramp = life
	layer.add_child(fireflies)


func _refresh_fireflies() -> void:
	if fireflies == null:
		return
	fireflies.emitting = GameState.is_night() and (_biome == WorldGen.Biome.FOREST or _biome == WorldGen.Biome.LAKE)
