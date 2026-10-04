class_name MapView
extends Control
## Мапа світу: зображення з WorldGen + маркери знайдених звірів і гравця.
## Використовується і як міні-мапа в HUD, і як велика мапа (show_names = true).

## Підписи імен звірів і назв біомів.
@export var show_names: bool = false
@export var marker_scale: float = 1.0

const BIOME_NAMES: Array[String] = ["Ліс", "Пустеля", "Озеро", "Сніги"]
const REDRAW_INTERVAL: float = 0.1

## Спільна текстура для всіх MapView (мапа детермінована, будується один раз).
static var _map_texture: ImageTexture

var player: Node2D
var _timer: float = 0.0
var _facing: Vector2 = Vector2.RIGHT
var _last_player_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _map_texture == null:
		_map_texture = ImageTexture.create_from_image(GameState.world_gen.build_map_image())
	GameState.animal_discovered.connect(_on_changed)
	GameState.animal_forgotten.connect(_on_changed)
	GameState.animal_updated.connect(_on_changed)
	resized.connect(queue_redraw)


func _on_changed(_id: String) -> void:
	queue_redraw()


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= REDRAW_INTERVAL and is_visible_in_tree():
		_timer = 0.0
		queue_redraw()


## Квадрат, у який вписана мапа.
func map_rect() -> Rect2:
	var side: float = minf(size.x, size.y)
	return Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side))


func world_to_map(world_pos: Vector2) -> Vector2:
	var r: Rect2 = map_rect()
	var world_size: Vector2 = GameState.world_gen.world_rect().size
	return r.position + world_pos / world_size * r.size


func _draw() -> void:
	var r: Rect2 = map_rect()
	draw_texture_rect(_map_texture, r, false)
	draw_rect(r, Color(0.05, 0.08, 0.06, 0.9), false, 2.0)
	var font: Font = get_theme_default_font()
	if show_names:
		for b: int in BIOME_NAMES.size():
			var center: Vector2 = r.position + WorldGen.BIOME_CENTERS[b] * r.size
			var label_pos: Vector2 = center + Vector2(-80, 0)
			draw_string_outline(font, label_pos, BIOME_NAMES[b].to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 160, 18, 6, Color(0, 0, 0, 0.35))
			draw_string(font, label_pos, BIOME_NAMES[b].to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 160, 18, Color(1, 1, 1, 0.55))

	var mr: float = 3.5 * marker_scale
	for rec: Dictionary in GameState.records.values():
		var id: String = rec["id"]
		var spot: Dictionary = GameState.get_spot(id)
		var sp: SpeciesData = GameState.species_of(id)
		if spot.is_empty() or sp == null:
			continue
		var p: Vector2 = world_to_map(GameState.record_position(rec, spot["position"]))
		draw_circle(p, mr + 1.5, Color(0.08, 0.08, 0.1))
		draw_circle(p, mr, sp.body_color)
		if GameState.has_voice(id):
			draw_circle(p, mr * 0.4, sp.accent_color)
		if show_names:
			var text: String = String(rec.get("name", ""))
			draw_string_outline(font, p + Vector2(mr + 3, 4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color(0, 0, 0, 0.8))
			draw_string(font, p + Vector2(mr + 3, 4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)

	if is_instance_valid(player):
		var wp: Vector2 = player.global_position
		var moved: Vector2 = wp - _last_player_pos
		if moved.length() > 1.0:
			_facing = moved.normalized()
		_last_player_pos = wp
		var p: Vector2 = world_to_map(wp)
		var s: float = 6.0 * marker_scale
		var side: Vector2 = _facing.orthogonal()
		var tri: PackedVector2Array = PackedVector2Array([p + _facing * s, p - _facing * s * 0.6 + side * s * 0.7, p - _facing * s * 0.6 - side * s * 0.7])
		draw_colored_polygon(tri, Color.WHITE)
		var inner: PackedVector2Array = PackedVector2Array([p + _facing * s * 0.6, p - _facing * s * 0.3 + side * s * 0.4, p - _facing * s * 0.3 - side * s * 0.4])
		draw_colored_polygon(inner, Color("e67e22"))
