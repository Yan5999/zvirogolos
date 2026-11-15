class_name AchievementsPanel
extends ModalPanel
## Список досягнень: отримані — з датою, решта — з описом умови.

var _rows: Array[Dictionary] = []


func _init() -> void:
	panel_size = Vector2(720, 600)


func _build_content() -> void:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for a: Dictionary in AchievementDB.ALL:
		var row: PanelContainer = PanelContainer.new()
		list.add_child(row)
		var h: HBoxContainer = HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		row.add_child(h)
		var mark: Label = Label.new()
		mark.custom_minimum_size = Vector2(32, 0)
		mark.add_theme_font_size_override("font_size", 24)
		h.add_child(mark)
		var texts: VBoxContainer = VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(texts)
		var title: Label = Label.new()
		title.add_theme_font_size_override("font_size", 18)
		title.text = a["title"]
		texts.add_child(title)
		var desc: Label = Label.new()
		desc.add_theme_font_size_override("font_size", 13)
		desc.text = a["desc"]
		texts.add_child(desc)
		var date: Label = Label.new()
		date.add_theme_font_size_override("font_size", 13)
		h.add_child(date)
		_rows.append({"id": a["id"], "row": row, "mark": mark, "title": title, "desc": desc, "date": date})


func unlocked_count() -> int:
	return GameState.achievements.size()


func row_count() -> int:
	return _rows.size()


func _refresh() -> void:
	title_label.text = "Досягнення: %d / %d" % [GameState.achievements.size(), _rows.size()]
	for r: Dictionary in _rows:
		var got: bool = GameState.achievements.has(r["id"])
		(r["mark"] as Label).text = "★" if got else "○"
		(r["mark"] as Label).modulate = Color(1.0, 0.82, 0.3) if got else Color(0.5, 0.55, 0.62)
		(r["row"] as Control).modulate = Color.WHITE if got else Color(1, 1, 1, 0.6)
		(r["date"] as Label).text = String(GameState.achievements.get(r["id"], "")).replace("T", " ").left(10) if got else ""
