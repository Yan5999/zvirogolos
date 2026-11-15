class_name AlbumPanel
extends ModalPanel
## Альбом: картка для кожного з 30 видів — портрет або власне фото гравця, ім'я, статус МСОП,
## кнопка прослуховування голосу. Невідомі види — силует із «?».

const BIOME_NAMES: Array[String] = ["Ліс", "Пустеля", "Озеро", "Сніги"]
const THUMB_WIDTH: int = 280

var _stats: Label
var _grid: GridContainer
var _cards: Array[Dictionary] = []
var _textures: Dictionary = {}


func _init() -> void:
	panel_size = Vector2(920, 600)


func _build_content() -> void:
	_stats = Label.new()
	content.add_child(_stats)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_grid)
	for biome: int in 4:
		for s: SpeciesData in GameState.SPECIES_DB.by_biome(biome):
			_cards.append(_make_card(s))


func _make_card(s: SpeciesData) -> Dictionary:
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(160, 188)
	_grid.add_child(card)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	var picture: Control = Control.new()
	picture.custom_minimum_size = Vector2(140, 84)
	box.add_child(picture)
	var portrait: SpeciesPortrait = SpeciesPortrait.new()
	portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	picture.add_child(portrait)
	var photo: TextureRect = TextureRect.new()
	photo.set_anchors_preset(Control.PRESET_FULL_RECT)
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	photo.visible = false
	picture.add_child(photo)
	var name_label: Label = Label.new()
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.clip_text = true
	box.add_child(name_label)
	var sub: Label = Label.new()
	sub.add_theme_font_size_override("font_size", 11)
	sub.clip_text = true
	box.add_child(sub)
	var play: Button = Button.new()
	play.text = "▶ Голос"
	play.pressed.connect(_play.bind(s))
	box.add_child(play)
	return {"species": s, "card": card, "portrait": portrait, "photo": photo, "name": name_label, "sub": sub, "play": play}


func card_count() -> int:
	return _cards.size()


func _record_of(s: SpeciesData) -> Dictionary:
	for rec: Dictionary in GameState.records.values():
		if StringName(String(rec.get("species", ""))) == s.id:
			return rec
	return {}


func _play(s: SpeciesData) -> void:
	var rec: Dictionary = _record_of(s)
	if rec.is_empty():
		return
	var stream: AudioStreamWAV = GameState.get_voice(String(rec["id"]))
	if stream:
		AudioManager.play_preview(stream, s.base_pitch)


func _texture_for(file_name: String) -> Texture2D:
	if _textures.has(file_name):
		return _textures[file_name]
	var img: Image = SaveManager.load_photo(file_name)
	if img == null:
		return null
	img.resize(THUMB_WIDTH, int(float(THUMB_WIDTH) * img.get_height() / img.get_width()), Image.INTERPOLATE_BILINEAR)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_textures[file_name] = tex
	return tex


func _refresh() -> void:
	var found: int = 0
	for c: Dictionary in _cards:
		var s: SpeciesData = c["species"]
		var rec: Dictionary = _record_of(s)
		var is_found: bool = not rec.is_empty()
		if is_found:
			found += 1
		(c["portrait"] as SpeciesPortrait).setup(s, not is_found)
		var photo: TextureRect = c["photo"]
		var file_name: String = String(rec.get("photo", ""))
		var tex: Texture2D = _texture_for(file_name) if not file_name.is_empty() else null
		photo.texture = tex
		photo.visible = tex != null
		(c["name"] as Label).text = String(rec.get("name", "")) if is_found else "???"
		(c["sub"] as Label).text = "%s · МСОП %s" % [BIOME_NAMES[s.biome], SpeciesData.Status.keys()[s.status]] if is_found else BIOME_NAMES[s.biome]
		(c["play"] as Button).visible = is_found and GameState.has_voice(String(rec.get("id", "")))
		(c["card"] as Control).tooltip_text = "%s (%s)\n%s" % [s.display_name, s.latin_name, s.description] if is_found else "Ще не знайдено"
	title_label.text = "Альбом тварин"
	_stats.text = "Знайдено: %d / %d  ·  Фото зроблено: %d  (F — сфотографувати)" % [found, _cards.size(), int(GameState.stats["photos"])]
