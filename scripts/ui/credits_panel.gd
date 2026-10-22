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
	body.bbcode_enabled = false
	body.fit_content = false
	body.scroll_active = true
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(0, 300)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.text = _credits_text()
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


func _credits_text() -> String:
	var path := "res://ASSETS.md"
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f:
			return f.get_as_text()
	return "The Frontier\nOriginal code (MIT). CC0 textures and HDRI from Poly Haven. Self-made meshes and audio."
