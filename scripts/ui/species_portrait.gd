class_name SpeciesPortrait
extends Control
## Мініатюрний портрет виду для альбому: кольоровий — для знайденого, силует із «?» — для невідомого.

const BIOME_TINTS: Array[Color] = [Color("2c4a30"), Color("7a6439"), Color("2f5170"), Color("8fa3b3")]

var species: SpeciesData
var silhouette: bool = false


func setup(p_species: SpeciesData, p_silhouette: bool) -> void:
	species = p_species
	silhouette = p_silhouette
	queue_redraw()


func _draw() -> void:
	if species == null:
		return
	var tint: Color = BIOME_TINTS[clampi(species.biome, 0, 3)]
	draw_rect(Rect2(Vector2.ZERO, size), tint.darkened(0.15 if not silhouette else 0.45))
	draw_set_transform(size * 0.5 + Vector2(0, 8), 0.0, Vector2(2.3, 2.3))
	var dark: Color = Color(0.07, 0.08, 0.11)
	var body_col: Color = dark if silhouette else species.body_color
	var belly_col: Color = dark if silhouette else species.belly_color
	var accent_col: Color = dark if silhouette else species.accent_color
	var head_col: Color = dark if silhouette else (species.head_color if species.head_color.a > 0.0 else species.body_color)
	DrawUtil.draw_ellipse(self, Vector2.ZERO, Vector2(15, 11), body_col)
	DrawUtil.draw_ellipse(self, Vector2(2, 4), Vector2(9, 6), belly_col)
	draw_circle(Vector2(9, -10), 8, head_col)
	draw_circle(Vector2(-12, 6), 3, accent_col)
	if not silhouette:
		draw_circle(Vector2(12, -11), 2.5, Color.WHITE)
		draw_circle(Vector2(13, -11), 1.3, Color("1e1e24"))
	else:
		draw_string(ThemeDB.fallback_font, Vector2(-4, -6), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.6, 0.66, 0.78))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
