class_name MainMenu
extends Control


func _ready() -> void:
	if not DisplayServer.get_name() == "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.07, 0.09)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(640, 0)
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)
	var title := Label.new()
	title.text = "THE FRONTIER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 46)
	ThemeUtil.font_color(title, Color(0.35, 0.92, 0.82))
	box.add_child(title)
	var sub := Label.new()
	sub.text = "Hold the core. Spend the calm. Leave if you can."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 16)
	ThemeUtil.font_color(sub, Color(0.75, 0.78, 0.72))
	box.add_child(sub)
	box.add_child(HSeparator.new())
	for mode in ModeCatalog.all():
		var button := Button.new()
		button.text = "%s\n%s" % [mode.display_name, mode.description]
		button.custom_minimum_size = Vector2(0, 72)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_start.bind(mode.id))
		box.add_child(button)
	var quit := Button.new()
	quit.text = "Quit"
	quit.pressed.connect(func() -> void: get_tree().quit())
	box.add_child(quit)
	var help := Label.new()
	help.text = "WASD move · mouse look · Shift sprint · Space jump · LMB fire · R reload · 1/2 weapons · B build · wheel or 3–7 cycle · LMB place · X/RMB dismantle · E gather/relic · Esc pause"
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_font_size_override("font_size", 13)
	ThemeUtil.font_color(help, Color(0.55, 0.6, 0.62))
	box.add_child(help)


func _start(mode_id: String) -> void:
	Session.selected_mode_id = mode_id
	Session.start_run(mode_id)
	get_tree().change_scene_to_file("res://scenes/world/arena.tscn")
