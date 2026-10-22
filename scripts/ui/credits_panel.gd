class_name CreditsPanel
extends PanelContainer

signal closed


func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(520, 420)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_stylebox_override("panel", ThemeUtil.panel(Color(0.04, 0.05, 0.07, 0.94)))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	var title := Label.new()
	title.text = "CREDITS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	ThemeUtil.font_color(title, Color(0.85, 0.95, 0.92))
	box.add_child(title)
	var body := RichTextLabel.new()
	body.name = "CreditsBody"
	body.bbcode_enabled = true
	body.fit_content = false
	body.scroll_active = true
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(0, 300)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.text = markdown_to_bbcode(_credits_source())
	body.add_theme_font_size_override("normal_font_size", 13)
	body.add_theme_color_override("default_color", Color(0.82, 0.84, 0.8))
	box.add_child(body)
	var back := ThemeUtil.menu_button("Back")
	back.pressed.connect(func() -> void:
		Sfx.play("ui_back")
		visible = false
		closed.emit()
	)
	box.add_child(back)


func _credits_source() -> String:
	for path in ["res://assets/CREDITS.md", "res://ASSETS.md"]:
		if FileAccess.file_exists(path):
			var f := FileAccess.open(path, FileAccess.READ)
			if f:
				return f.get_as_text()
	return "The Frontier\nOriginal code (MIT). CC0 textures and HDRI from Poly Haven. Self-made meshes and audio."


static func markdown_to_bbcode(md: String) -> String:
	var out: PackedStringArray = PackedStringArray()
	var in_table := false
	for raw in md.split("\n"):
		var line := raw.strip_edges()
		if line.is_empty():
			if in_table:
				in_table = false
			out.append("")
			continue
		if line.begins_with("|") and line.find("---") != -1:
			continue
		if line.begins_with("|"):
			var cells: PackedStringArray = PackedStringArray()
			for cell in line.split("|"):
				var text := cell.strip_edges()
				if text != "":
					cells.append(_inline(text))
			if cells.is_empty():
				continue
			if not in_table:
				in_table = true
				if cells.size() == 1:
					out.append("[b]%s[/b]" % cells[0])
				else:
					var rest: PackedStringArray = PackedStringArray()
					for i in range(1, cells.size()):
						rest.append(cells[i])
					out.append("[b]%s[/b] — %s" % [cells[0], " · ".join(rest)])
			else:
				out.append("• %s" % " — ".join(cells))
			continue
		in_table = false
		if line.begins_with("# "):
			out.append("[font_size=20][b]%s[/b][/font_size]" % _inline(line.substr(2)))
		elif line.begins_with("## "):
			out.append("[font_size=16][b]%s[/b][/font_size]" % _inline(line.substr(3)))
		elif line.begins_with("### "):
			out.append("[b]%s[/b]" % _inline(line.substr(4)))
		elif line.begins_with("- "):
			out.append("• %s" % _inline(line.substr(2)))
		else:
			out.append(_inline(line))
	return "\n".join(out)


static func _inline(text: String) -> String:
	var escaped := text.replace("[", "(").replace("]", ")")
	var out := ""
	var i := 0
	while i < escaped.length():
		if escaped.substr(i, 2) == "**":
			var close := escaped.find("**", i + 2)
			if close != -1:
				out += "[b]%s[/b]" % escaped.substr(i + 2, close - i - 2)
				i = close + 2
				continue
		if escaped.substr(i, 1) == "`":
			var close := escaped.find("`", i + 1)
			if close != -1:
				out += "[code]%s[/code]" % escaped.substr(i + 1, close - i - 1)
				i = close + 1
				continue
		out += escaped.substr(i, 1)
		i += 1
	return out
