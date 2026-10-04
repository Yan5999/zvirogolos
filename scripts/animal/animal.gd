class_name Animal
extends Node2D
## Животное на карте. Сначала спрятано в укрытии (куст/камень/нора/сугроб/камыш),
## при приближении игрока «выпрыгивает», затем живёт рядом с укрытием и бродит.
## Звук голоса запрашивается у AudioManager (пул плееров), см. этап 4.

signal discovered(animal: Animal)
signal reveal_finished(animal: Animal)

enum State { HIDDEN, REVEALING, ACTIVE }

const RUSTLE_DISTANCE: float = 230.0
const REVEAL_OFFSET: Vector2 = Vector2(26, 12)
## Минимальная пауза между проигрываниями голоса одного зверя (сек).
const VOICE_COOLDOWN: float = 6.0

var animal_id: String = ""
var species: SpeciesData
var state: State = State.HIDDEN
var display_name: String = ""

var _player: Player
var _time: float = 0.0
var _facing: float = 1.0
var _wander_target: Vector2 = Vector2.ZERO
var _wander_wait: float = 0.0
var _moving: bool = false
var _player_near: bool = false
var _last_voice_ms: int = -1000000

@onready var hideout: Node2D = $Hideout
@onready var creature: Node2D = $Creature
@onready var body: Node2D = $Creature/Body
@onready var name_label: Label = $Creature/NameLabel
@onready var discover_area: Area2D = $DiscoverArea
@onready var hear_area: Area2D = $Creature/HearArea
@onready var voice_notes: CPUParticles2D = $Creature/VoiceNotes
@onready var reveal_particles: CPUParticles2D = $RevealParticles
@onready var screen_notifier: VisibleOnScreenNotifier2D = $ScreenNotifier


func _ready() -> void:
	hideout.draw.connect(_on_hideout_draw)
	body.draw.connect(_on_body_draw)
	discover_area.body_entered.connect(_on_discover_body_entered)
	hear_area.body_entered.connect(_on_hear_body_entered)
	hear_area.body_exited.connect(_on_hear_body_exited)
	# Оптимизация: визуальная логика (шелест, брожение, анимация) только на экране.
	# Физические зоны при этом продолжают работать.
	screen_notifier.screen_entered.connect(set_process.bind(true))
	screen_notifier.screen_exited.connect(set_process.bind(false))
	set_process(false)


func setup(id: String, sp: SpeciesData, record: Dictionary, player: Player) -> void:
	animal_id = id
	species = sp
	_player = player
	_time = randf() * 10.0
	voice_notes.color = sp.accent_color.lightened(0.2)
	if record.is_empty():
		_set_hidden()
	else:
		state = State.ACTIVE
		display_name = String(record.get("name", sp.display_name))
		creature.visible = true
		var saved: Vector2 = GameState.record_position(record, global_position + REVEAL_OFFSET)
		creature.position = (saved - global_position).limit_length(sp.wander_radius)
		_wander_target = creature.position
		_update_label()
	hideout.queue_redraw()
	body.queue_redraw()


## Обновить имя/данные после изменения записи (переименование и т.п.).
func refresh(record: Dictionary) -> void:
	if record.is_empty():
		return
	display_name = String(record.get("name", display_name))
	_update_label()


## Вернуть в укрытие (удаление из зоопарка).
func hide_again() -> void:
	_set_hidden()


func creature_global_position() -> Vector2:
	return creature.global_position


func is_active() -> bool:
	return state == State.ACTIVE


func _set_hidden() -> void:
	state = State.HIDDEN
	creature.visible = false
	creature.position = Vector2.ZERO
	hideout.modulate.a = 1.0
	display_name = ""
	_update_label()
	# Если игрок стоит прямо в зоне — не открываем мгновенно повторно, ждём выхода/входа.


func reveal() -> void:
	if state != State.HIDDEN:
		return
	state = State.REVEALING
	discovered.emit(self)
	display_name = species.display_name
	creature.visible = true
	creature.position = Vector2.ZERO
	creature.scale = Vector2(0.1, 0.1)
	creature.modulate.a = 0.0
	body.position = Vector2.ZERO
	reveal_particles.restart()

	var tw: Tween = create_tween()
	tw.tween_property(hideout, "scale", Vector2(1.3, 0.75), 0.07)
	tw.tween_property(hideout, "scale", Vector2(0.85, 1.15), 0.07)
	tw.tween_property(hideout, "scale", Vector2.ONE, 0.1)
	tw.tween_property(creature, "modulate:a", 1.0, 0.12)
	tw.parallel().tween_property(creature, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(creature, "position", REVEAL_OFFSET, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(body, "position:y", -18.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(body, "position:y", 0.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(hideout, "modulate:a", 0.8, 0.3)
	tw.tween_callback(_on_reveal_done)


func _on_reveal_done() -> void:
	state = State.ACTIVE
	_wander_target = creature.position
	_wander_wait = randf_range(1.0, 2.5)
	_update_label()
	reveal_finished.emit(self)


func _on_discover_body_entered(b: Node2D) -> void:
	if b is Player and state == State.HIDDEN:
		reveal()


func _process(delta: float) -> void:
	_time += delta
	match state:
		State.HIDDEN:
			_rustle()
		State.ACTIVE:
			_wander(delta)
			_animate_body()
			# Игрок остался рядом и бегает вокруг — повторяем голос после кулдауна.
			if _player_near and _player and _player.is_moving():
				try_play_voice()


# --- Голос -------------------------------------------------------------------------

func _on_hear_body_entered(b: Node2D) -> void:
	if b is Player:
		_player_near = true
		try_play_voice()


func _on_hear_body_exited(b: Node2D) -> void:
	if b is Player:
		_player_near = false


func voice_cooldown_left() -> float:
	return maxf(0.0, VOICE_COOLDOWN - float(Time.get_ticks_msec() - _last_voice_ms) / 1000.0)


## Пытается проиграть записанный голос (с кулдауном и общим лимитом голосов).
func try_play_voice(force: bool = false) -> bool:
	if state != State.ACTIVE:
		return false
	if not force and voice_cooldown_left() > 0.0:
		return false
	var stream: AudioStreamWAV = GameState.get_voice(animal_id)
	if stream == null:
		return false
	if not AudioManager.play_voice_at(stream, creature, species.random_pitch()):
		return false
	_last_voice_ms = Time.get_ticks_msec()
	_hop()
	return true


func reset_voice_cooldown() -> void:
	_last_voice_ms = -1000000


func _hop() -> void:
	voice_notes.restart()
	var tw: Tween = create_tween()
	tw.tween_property(body, "position:y", -10.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(body, "position:y", 0.0, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _rustle() -> void:
	if _player == null:
		return
	var d: float = global_position.distance_to(_player.global_position)
	if d < RUSTLE_DISTANCE:
		var k: float = 1.0 - d / RUSTLE_DISTANCE
		hideout.rotation = sin(_time * 22.0) * 0.06 * k * (0.5 + 0.5 * sin(_time * 1.7))
	elif hideout.rotation != 0.0:
		hideout.rotation = 0.0


func _wander(delta: float) -> void:
	_moving = false
	if not species.wanders:
		return
	if _wander_wait > 0.0:
		_wander_wait -= delta
		return
	var to: Vector2 = _wander_target - creature.position
	var dist: float = to.length()
	if dist < 1.5:
		_wander_wait = randf_range(1.5, 4.5)
		_wander_target = _pick_wander_target()
		return
	_moving = true
	creature.position += to / dist * minf(species.wander_speed * delta, dist)
	if absf(to.x) > 0.5:
		_facing = signf(to.x)


func _pick_wander_target() -> Vector2:
	for i: int in 6:
		var p: Vector2 = Vector2.from_angle(randf() * TAU) * randf_range(18.0, species.wander_radius)
		if p.length() > 14.0 and GameState.world_gen.is_walkable_pos(global_position + p):
			return p
	return creature.position


func _animate_body() -> void:
	if _moving:
		body.position.y = -absf(sin(_time * 11.0)) * 2.5
		body.scale = Vector2(_facing, 1.0)
	else:
		body.position.y = 0.0
		body.scale = Vector2(_facing, 1.0 + sin(_time * 2.4) * 0.035)


func _update_label() -> void:
	name_label.text = display_name
	name_label.visible = state != State.HIDDEN and not display_name.is_empty()
	if species:
		name_label.position.y = -species.body_radii.y * 2.0 - 38.0


# --- Процедурный арт (заменяемый) ---------------------------------------------

func _on_body_draw() -> void:
	if species == null:
		return
	var s: SpeciesData = species
	DrawUtil.draw_ellipse(body, Vector2(0, 1), Vector2(s.body_radii.x * 0.9, 3.5), Color(0, 0, 0, 0.22))
	if s.sprite:
		body.draw_texture(s.sprite, -Vector2(s.sprite.get_width() * 0.5, s.sprite.get_height()))
		return
	var r: Vector2 = s.body_radii
	var c: Vector2 = Vector2(0, -r.y - 2.0)
	var outline: Color = s.body_color.darkened(0.5)
	var head_col: Color = s.head_color if s.head_color.a > 0.0 else s.body_color

	_draw_tail(s, c, r, outline)
	var foot: Color = s.body_color.darkened(0.35)
	DrawUtil.draw_ellipse(body, Vector2(-r.x * 0.45, -1.5), Vector2(3.5, 2.2), foot, 10)
	DrawUtil.draw_ellipse(body, Vector2(r.x * 0.45, -1.5), Vector2(3.5, 2.2), foot, 10)
	if s.feature == SpeciesData.Feature.SPIKES:
		for k: int in 7:
			var a: float = lerpf(PI * 1.05, PI * 1.95, float(k) / 6.0)
			var base: Vector2 = c + Vector2(cos(a) * r.x, sin(a) * r.y)
			var tip: Vector2 = c + Vector2(cos(a) * (r.x + 7.0), sin(a) * (r.y + 7.0))
			var side: Vector2 = Vector2(-sin(a), cos(a)) * 3.0
			body.draw_colored_polygon(PackedVector2Array([base - side, tip, base + side]), s.accent_color)
	DrawUtil.draw_ellipse(body, c, r + Vector2(1.5, 1.5), outline)
	DrawUtil.draw_ellipse(body, c, r, s.body_color)
	match s.feature:
		SpeciesData.Feature.HUMP:
			var hump: Vector2 = c + Vector2(-r.x * 0.1, -r.y * 0.8)
			DrawUtil.draw_ellipse(body, hump, Vector2(r.x * 0.48, r.y * 0.62) + Vector2(1.5, 1.5), outline)
			DrawUtil.draw_ellipse(body, hump, Vector2(r.x * 0.48, r.y * 0.62), s.body_color)
		SpeciesData.Feature.SHELL:
			var sc: Vector2 = c + Vector2(-r.x * 0.05, -r.y * 0.3)
			DrawUtil.draw_ellipse(body, sc, Vector2(r.x * 1.02, r.y * 1.0) + Vector2(1.5, 1.5), s.accent_color.darkened(0.4))
			DrawUtil.draw_ellipse(body, sc, Vector2(r.x * 1.02, r.y * 1.0), s.accent_color)
			for k: int in 3:
				var px: float = (float(k) - 1.0) * r.x * 0.6
				DrawUtil.draw_ellipse(body, sc + Vector2(px, -r.y * 0.15), Vector2(r.x * 0.24, r.y * 0.4), s.accent_color.lightened(0.18), 10)
		_:
			pass
	if s.feature != SpeciesData.Feature.SHELL:
		DrawUtil.draw_ellipse(body, c + Vector2(r.x * 0.15, r.y * 0.3), r * Vector2(0.6, 0.55), s.belly_color)

	var hr: float = maxf(6.0, r.y * 0.72) * s.head_scale
	var neck: float = s.neck_length * r.y
	var hc: Vector2 = c + Vector2(r.x * 0.7, -r.y * 0.75 - neck)
	if neck > 0.5:
		var n0: Vector2 = c + Vector2(r.x * 0.55, -r.y * 0.35)
		body.draw_line(n0, hc, outline, hr * 0.95 + 3.0)
		body.draw_line(n0, hc, head_col if s.neck_length > 1.0 else s.body_color, hr * 0.95)
	_draw_ears(s, hc, hr, head_col)
	body.draw_circle(hc, hr + 1.5, outline)
	body.draw_circle(hc, hr, head_col)
	if s.face_mask:
		DrawUtil.draw_ellipse(body, hc + Vector2(hr * 0.3, -hr * 0.12), Vector2(hr * 0.75, hr * 0.32), Color(0.12, 0.1, 0.1, 0.9))
	match s.feature:
		SpeciesData.Feature.CAP:
			DrawUtil.draw_ellipse(body, hc + Vector2(0, -hr * 0.55), Vector2(hr * 1.45, hr * 0.8), s.accent_color)
		SpeciesData.Feature.HORN:
			body.draw_colored_polygon(PackedVector2Array([hc + Vector2(-hr * 0.15, -hr * 0.8), hc + Vector2(hr * 0.2, -hr * 2.1), hc + Vector2(hr * 0.45, -hr * 0.7)]), s.accent_color)
		SpeciesData.Feature.ANTLERS:
			for side: float in [-0.35, 0.3]:
				var base: Vector2 = hc + Vector2(hr * side, -hr * 0.85)
				var tip: Vector2 = base + Vector2(-hr * 0.5 + side * hr, -hr * 2.0)
				body.draw_line(base, tip, s.accent_color.darkened(0.3), 2.6)
				for t: float in [0.4, 0.75]:
					var p: Vector2 = base.lerp(tip, t)
					body.draw_line(p, p + Vector2(hr * 0.55, -hr * 0.45), s.accent_color.darkened(0.3), 2.0)
		SpeciesData.Feature.BEAK:
			body.draw_colored_polygon(PackedVector2Array([hc + Vector2(hr * 0.7, -hr * 0.25), hc + Vector2(hr * 1.65, hr * 0.05), hc + Vector2(hr * 0.7, hr * 0.35)]), s.accent_color)
		SpeciesData.Feature.TUSKS:
			DrawUtil.draw_ellipse(body, hc + Vector2(hr * 0.6, hr * 0.35), Vector2(hr * 0.45, hr * 0.35), s.body_color.darkened(0.15))
			body.draw_line(hc + Vector2(hr * 0.45, hr * 0.5), hc + Vector2(hr * 0.4, hr * 1.7), s.accent_color, 3.0)
			body.draw_line(hc + Vector2(hr * 0.8, hr * 0.5), hc + Vector2(hr * 0.8, hr * 1.7), s.accent_color, 3.0)
		_:
			pass
	var eye: Vector2 = hc + Vector2(hr * 0.35, -hr * 0.12)
	body.draw_circle(eye, hr * 0.3, Color.WHITE)
	body.draw_circle(eye + Vector2(hr * 0.08, 0), hr * 0.17, Color("1e1e24"))
	body.draw_circle(eye + Vector2(hr * 0.02, -hr * 0.08), hr * 0.06, Color.WHITE)
	if s.feature != SpeciesData.Feature.BEAK and s.feature != SpeciesData.Feature.TUSKS:
		body.draw_circle(hc + Vector2(hr * 0.95, hr * 0.15), hr * 0.14, Color("2a2020"))
		body.draw_circle(hc + Vector2(hr * 0.15, hr * 0.4), hr * 0.18, Color(1.0, 0.55, 0.6, 0.45))


func _draw_ears(s: SpeciesData, hc: Vector2, hr: float, col: Color) -> void:
	var er: float = hr * s.ear_scale
	var ear_col: Color = col.darkened(0.12)
	match s.ears:
		SpeciesData.Ears.POINTY:
			for ox: float in [-0.55, 0.25]:
				var b: Vector2 = hc + Vector2(hr * ox, -hr * 0.55)
				var tip: Vector2 = b + Vector2(er * 0.05, -er * 1.05)
				body.draw_colored_polygon(PackedVector2Array([b + Vector2(-er * 0.35, 0), tip, b + Vector2(er * 0.4, 0)]), ear_col)
				body.draw_colored_polygon(PackedVector2Array([b + Vector2(-er * 0.15, 0), b + Vector2(er * 0.05, -er * 0.7), b + Vector2(er * 0.2, 0)]), s.belly_color)
				if s.ear_tufts:
					body.draw_line(tip, tip + Vector2(0, -er * 0.45), Color("1e1e1e"), 2.0)
		SpeciesData.Ears.ROUND:
			body.draw_circle(hc + Vector2(-hr * 0.6, -hr * 0.8), er * 0.42, ear_col)
			body.draw_circle(hc + Vector2(hr * 0.35, -hr * 0.9), er * 0.42, ear_col)
		SpeciesData.Ears.LONG:
			DrawUtil.draw_ellipse(body, hc + Vector2(-hr * 0.45, -hr * 0.6 - er * 0.95), Vector2(er * 0.28, er * 0.95), ear_col, 14)
			DrawUtil.draw_ellipse(body, hc + Vector2(hr * 0.15, -hr * 0.7 - er * 0.95), Vector2(er * 0.28, er * 0.95), col.darkened(0.05), 14)
		_:
			pass


func _draw_tail(s: SpeciesData, c: Vector2, r: Vector2, outline: Color) -> void:
	match s.tail:
		SpeciesData.Tail.SHORT:
			DrawUtil.draw_ellipse(body, c + Vector2(-r.x * 0.98, -r.y * 0.2), Vector2(r.x * 0.22, r.y * 0.25), s.body_color.darkened(0.1), 10)
		SpeciesData.Tail.BUSHY:
			var tc: Vector2 = c + Vector2(-r.x * 1.1, -r.y * 0.6)
			DrawUtil.draw_ellipse(body, tc, Vector2(r.x * 0.62, r.y * 0.5) + Vector2(1.5, 1.5), outline)
			DrawUtil.draw_ellipse(body, tc, Vector2(r.x * 0.62, r.y * 0.5), s.body_color)
			DrawUtil.draw_ellipse(body, tc + Vector2(-r.x * 0.42, -r.y * 0.15), Vector2(r.x * 0.2, r.y * 0.25), s.belly_color, 10)
		SpeciesData.Tail.THIN:
			body.draw_polyline(PackedVector2Array([c + Vector2(-r.x * 0.9, 0), c + Vector2(-r.x * 1.5, r.y * 0.35), c + Vector2(-r.x * 2.0, r.y * 0.1)]), s.body_color.darkened(0.15), 3.0)
		SpeciesData.Tail.FLAT:
			DrawUtil.draw_ellipse(body, c + Vector2(-r.x * 1.15, r.y * 0.55), Vector2(r.x * 0.45, r.y * 0.24), s.accent_color, 12)
		_:
			pass


func _on_hideout_draw() -> void:
	if species == null:
		return
	match species.hideout:
		SpeciesData.Hideout.BUSH:
			DrawUtil.draw_ellipse(hideout, Vector2(0, 2), Vector2(22, 6), Color(0, 0, 0, 0.2))
			hideout.draw_circle(Vector2(-11, -8), 11, Color("2f7030"))
			hideout.draw_circle(Vector2(11, -9), 12, Color("357a33"))
			hideout.draw_circle(Vector2(0, -17), 12, Color("3e8a3a"))
			hideout.draw_circle(Vector2(-4, -20), 5, Color("56a84c"))
			hideout.draw_circle(Vector2(7, -6), 2, Color("e85a6a"))
		SpeciesData.Hideout.ROCK:
			DrawUtil.draw_ellipse(hideout, Vector2(0, 2), Vector2(22, 6), Color(0, 0, 0, 0.2))
			DrawUtil.draw_ellipse(hideout, Vector2(-4, -10), Vector2(20, 13), Color("7d756b"))
			DrawUtil.draw_ellipse(hideout, Vector2(9, -6), Vector2(11, 8), Color("8f877b"))
			DrawUtil.draw_ellipse(hideout, Vector2(-9, -15), Vector2(8, 4), Color("a39c90"))
		SpeciesData.Hideout.BURROW:
			DrawUtil.draw_ellipse(hideout, Vector2(0, -4), Vector2(20, 9), Color("8a6440"))
			DrawUtil.draw_ellipse(hideout, Vector2(0, -3), Vector2(11, 5), Color("2a1c12"))
			hideout.draw_circle(Vector2(-16, -6), 3, Color("a07a52"))
			hideout.draw_circle(Vector2(15, -5), 2.5, Color("a07a52"))
		SpeciesData.Hideout.SNOWDRIFT:
			DrawUtil.draw_ellipse(hideout, Vector2(0, 2), Vector2(24, 6), Color(0.3, 0.45, 0.6, 0.25))
			DrawUtil.draw_ellipse(hideout, Vector2(-8, -8), Vector2(15, 10), Color("e9f2fa"))
			DrawUtil.draw_ellipse(hideout, Vector2(9, -6), Vector2(13, 8), Color("ffffff"))
			DrawUtil.draw_ellipse(hideout, Vector2(-10, -12), Vector2(6, 3), Color("c9dcef"))
		SpeciesData.Hideout.REEDS:
			DrawUtil.draw_ellipse(hideout, Vector2(0, 1), Vector2(20, 5), Color(0, 0, 0, 0.18))
			for k: int in 7:
				var x: float = -15.0 + k * 5.0
				var top: float = -30.0 + float((k * 7) % 3) * 5.0
				hideout.draw_line(Vector2(x, 0), Vector2(x + 2.0, top), Color("5d7f3a"), 2.0)
				hideout.draw_line(Vector2(x + 2.0, top), Vector2(x + 2.0, top + 6.0), Color("7a5534"), 3.0)
