class_name SettingsPanel
extends PanelContainer

signal closed


func _ready() -> void:
	visible = false
	add_theme_stylebox_override("panel", ThemeUtil.panel(Color(0.04, 0.05, 0.07, 0.92)))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	var title := Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	ThemeUtil.font_color(title, Color(0.85, 0.95, 0.92))
	box.add_child(title)
	_slider(box, "Mouse sensitivity", GameSettings.mouse_sensitivity, 0.3, 2.5, func(v: float) -> void: GameSettings.set_mouse_sensitivity(v))
	_slider(box, "Field of view", GameSettings.fov, 60.0, 100.0, func(v: float) -> void: GameSettings.set_fov(v), 0)
	_slider(box, "Master volume", GameSettings.master_volume, 0.0, 1.0, func(v: float) -> void: GameSettings.set_master_volume(v))
	_slider(box, "Effects volume", GameSettings.sfx_volume, 0.0, 1.0, func(v: float) -> void: GameSettings.set_sfx_volume(v))
	var q_label := Label.new()
	q_label.text = "Graphics quality"
	ThemeUtil.font_color(q_label, Color(0.7, 0.78, 0.76))
	box.add_child(q_label)
	var quality := OptionButton.new()
	quality.add_item("Low", GameSettings.Quality.LOW)
	quality.add_item("Medium", GameSettings.Quality.MEDIUM)
	quality.add_item("High", GameSettings.Quality.HIGH)
	quality.add_item("Ultra", GameSettings.Quality.ULTRA)
	quality.select(GameSettings.quality)
	quality.item_selected.connect(func(i: int) -> void:
		Sfx.play("ui_click")
		GameSettings.set_quality(i)
	)
	ThemeUtil.style_option(quality)
	box.add_child(quality)
	var back := ThemeUtil.menu_button("Back")
	back.pressed.connect(func() -> void:
		Sfx.play("ui_back")
		visible = false
		closed.emit()
	)
	box.add_child(back)


func _slider(parent: Control, label_text: String, value: float, mn: float, mx: float, cb: Callable, decimals: int = 2) -> void:
	var row := VBoxContainer.new()
	var label := Label.new()
	label.text = "%s  %s" % [label_text, _fmt(value, decimals)]
	ThemeUtil.font_color(label, Color(0.72, 0.8, 0.78))
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = mn
	slider.max_value = mx
	slider.step = 0.01 if decimals > 0 else 1.0
	slider.value = value
	slider.custom_minimum_size = Vector2(0, 18)
	slider.value_changed.connect(func(v: float) -> void:
		label.text = "%s  %s" % [label_text, _fmt(v, decimals)]
		cb.call(v)
	)
	row.add_child(slider)
	parent.add_child(row)


func _fmt(v: float, decimals: int) -> String:
	if decimals <= 0:
		return "%d" % int(round(v))
	return "%.2f" % v
