class_name DrawUtil
extends RefCounted
## Мелкие помощники для процедурного рисования в _draw().


static func ellipse(center: Vector2, radii: Vector2, segments: int = 20) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	pts.resize(segments)
	for i: int in segments:
		var a: float = TAU * float(i) / float(segments)
		pts[i] = center + Vector2(cos(a) * radii.x, sin(a) * radii.y)
	return pts


static func draw_ellipse(item: CanvasItem, center: Vector2, radii: Vector2, color: Color, segments: int = 20) -> void:
	item.draw_colored_polygon(ellipse(center, radii, segments), color)
