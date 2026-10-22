class_name ThemeUtil
extends RefCounted


static func font_color(label: Label, color: Color) -> void:
	label.add_theme_color_override("font_color", color)


static func panel(color: Color = Color(0.05, 0.07, 0.09, 0.78)) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = Color(0.25, 0.85, 0.75, 0.35)
	box.set_border_width_all(1)
	box.set_corner_radius_all(6)
	box.set_content_margin_all(10)
	return box
