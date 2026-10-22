class_name ThemeUtil
extends RefCounted


static func font_color(label: Label, color: Color) -> void:
	label.add_theme_color_override("font_color", color)


static func readable_font(label: Label, color: Color, size: int = 0) -> void:
	if size > 0:
		label.add_theme_font_size_override("font_size", size)
	font_color(label, color)
	label.add_theme_constant_override("outline_size", 7)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03, 0.94))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.72))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.add_theme_constant_override("shadow_outline_size", 3)


static func film_bar(color: Color = Color(0.02, 0.025, 0.03, 0.18)) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = Color(0.86, 0.68, 0.38, 0.28)
	box.border_width_left = 0
	box.border_width_top = 0
	box.border_width_right = 0
	box.border_width_bottom = 1
	box.set_corner_radius_all(0)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 4
	box.content_margin_bottom = 5
	box.shadow_color = Color(0, 0, 0, 0.28)
	box.shadow_size = 4
	return box


static func overlay_plate(color: Color = Color(0.03, 0.035, 0.04, 0.22)) -> StyleBoxFlat:
	return film_bar(color)


static func panel(color: Color = Color(0.05, 0.07, 0.09, 0.78)) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = Color(0.35, 0.85, 0.78, 0.45)
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	box.set_content_margin_all(12)
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 8
	return box


static func menu_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 40)
	_style_button(button)
	button.mouse_entered.connect(func() -> void: Sfx.play("ui_hover", 1.05))
	return button


static func _style_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _btn_box(Color(0.08, 0.12, 0.14, 0.92), Color(0.28, 0.7, 0.68, 0.45)))
	button.add_theme_stylebox_override("hover", _btn_box(Color(0.14, 0.28, 0.3, 0.96), Color(0.45, 0.95, 0.88, 0.85)))
	button.add_theme_stylebox_override("pressed", _btn_box(Color(0.2, 0.42, 0.4, 1.0), Color(0.95, 0.75, 0.35, 0.9)))
	button.add_theme_stylebox_override("focus", _btn_box(Color(0.12, 0.22, 0.24, 0.96), Color(0.55, 0.95, 0.88, 0.7)))
	button.add_theme_color_override("font_color", Color(0.88, 0.93, 0.91))
	button.add_theme_color_override("font_hover_color", Color(0.98, 1.0, 0.94))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.9, 0.55))


static func style_option(button: OptionButton) -> void:
	_style_button(button)


static func _btn_box(bg: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(6)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box
