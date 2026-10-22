class_name MainMenu
extends Node3D

var _camera: Camera3D
var _orbit: float = 0.35
var _home: Control
var _play: Control
var _settings: SettingsPanel
var _credits: CreditsPanel
var _subtitle: Label


func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	TitleBackdrop.build(self)
	_camera = Camera3D.new()
	_camera.name = "CinematicCamera"
	_camera.fov = 48.0
	_camera.current = true
	add_child(_camera)
	_place_camera(0.0)
	_build_ui()


func freeze_cinematic(orbit: float = 0.35) -> void:
	_orbit = orbit
	set_process(false)
	if _camera:
		_place_camera(_orbit)


func _process(delta: float) -> void:
	_orbit += delta * 0.045
	_place_camera(_orbit)
	var core := get_node_or_null("TitleCore") as Node3D
	if core:
		var heart := VisualKit.find_node(core, "Heart")
		if heart:
			heart.rotate_y(delta * 0.7)


func _place_camera(t: float) -> void:
	var radius := 22.0 + sin(t * 0.65) * 2.2
	var height := 7.4 + sin(t * 0.4) * 1.3
	var angle := t
	_camera.position = Vector3(cos(angle) * radius, height, sin(angle) * radius)
	_camera.look_at(Vector3(0.0, 2.4, 0.0), Vector3.UP)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "MenuLayer"
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var veil := ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.02, 0.03, 0.04, 0.22)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(veil)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	panel.anchor_right = 0.0
	panel.offset_left = 36
	panel.offset_right = 460
	panel.offset_top = 48
	panel.offset_bottom = -48
	panel.add_theme_stylebox_override("panel", ThemeUtil.panel(Color(0.03, 0.045, 0.055, 0.78)))
	root.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)
	var logo_row := HBoxContainer.new()
	logo_row.add_theme_constant_override("separation", 12)
	col.add_child(logo_row)
	var emblem := TextureRect.new()
	emblem.custom_minimum_size = Vector2(56, 56)
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists("res://icon.svg"):
		emblem.texture = load("res://icon.svg")
	logo_row.add_child(emblem)
	var titles := VBoxContainer.new()
	logo_row.add_child(titles)
	var title := Label.new()
	title.text = "THE FRONTIER"
	title.add_theme_font_size_override("font_size", 34)
	ThemeUtil.font_color(title, Color(0.45, 0.96, 0.88))
	titles.add_child(title)
	_subtitle = Label.new()
	_subtitle.text = "A dusk outpost. A living core. Hold the line."
	_subtitle.add_theme_font_size_override("font_size", 14)
	ThemeUtil.font_color(_subtitle, Color(0.78, 0.72, 0.62))
	titles.add_child(_subtitle)
	col.add_child(HSeparator.new())
	_home = VBoxContainer.new()
	_home.add_theme_constant_override("separation", 8)
	col.add_child(_home)
	_home.add_child(_btn("Play", _show_play))
	_home.add_child(_btn("Settings", _show_settings))
	_home.add_child(_btn("Credits", _show_credits))
	_home.add_child(_btn("Quit", func() -> void: get_tree().quit()))
	_play = VBoxContainer.new()
	_play.visible = false
	_play.add_theme_constant_override("separation", 8)
	col.add_child(_play)
	var play_title := Label.new()
	play_title.text = "SELECT MODE"
	play_title.add_theme_font_size_override("font_size", 16)
	ThemeUtil.font_color(play_title, Color(0.9, 0.86, 0.7))
	_play.add_child(play_title)
	for mode in ModeCatalog.all():
		var button := ThemeUtil.menu_button("%s\n%s" % [mode.display_name, mode.description])
		button.custom_minimum_size = Vector2(0, 64)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(_start.bind(mode.id))
		_play.add_child(button)
	_play.add_child(_btn("Back", _show_home, true))
	_settings = SettingsPanel.new()
	_settings.visible = false
	_settings.closed.connect(_show_home)
	col.add_child(_settings)
	_credits = CreditsPanel.new()
	_credits.visible = false
	_credits.closed.connect(_show_home)
	col.add_child(_credits)
	var help := Label.new()
	help.text = "WASD move · mouse look · Shift sprint · Space jump · LMB fire · R reload · 1/2 weapons · B build · wheel or 3–7 cycle · LMB place · X/RMB dismantle · E gather/relic · Esc pause"
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_font_size_override("font_size", 12)
	ThemeUtil.font_color(help, Color(0.55, 0.6, 0.62))
	col.add_child(help)


func _btn(text: String, cb: Callable, back: bool = false) -> Button:
	var button := ThemeUtil.menu_button(text)
	button.pressed.connect(func() -> void:
		Sfx.play("ui_back" if back else "ui_click")
		cb.call()
	)
	return button


func _show_home() -> void:
	_home.visible = true
	_play.visible = false
	_settings.visible = false
	_credits.visible = false


func _show_play() -> void:
	_home.visible = false
	_play.visible = true
	_settings.visible = false
	_credits.visible = false


func _show_settings() -> void:
	_home.visible = false
	_play.visible = false
	_settings.visible = true
	_credits.visible = false


func _show_credits() -> void:
	_home.visible = false
	_play.visible = false
	_settings.visible = false
	_credits.visible = true


func _start(mode_id: String) -> void:
	Sfx.play("ui_click", 0.9)
	Session.selected_mode_id = mode_id
	Session.start_run(mode_id)
	get_tree().change_scene_to_file("res://scenes/world/arena.tscn")
