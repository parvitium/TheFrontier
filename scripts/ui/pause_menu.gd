class_name PauseMenu
extends CanvasLayer

var _root: Control


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(320, 0)
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeUtil.readable_font(title, Color(0.9, 0.95, 0.92), 28)
	box.add_child(title)
	_btn(box, "Resume", _resume)
	_btn(box, "Settings", _settings)
	_btn(box, "Restart mode", _restart)
	_btn(box, "Main menu", _menu)
	var settings := SettingsPanel.new()
	settings.name = "Settings"
	settings.visible = false
	box.add_child(settings)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and Session.state.is_running():
		if get_tree().paused:
			_resume()
		else:
			_pause()
		get_viewport().set_input_as_handled()


func _pause() -> void:
	Session.set_paused(true)
	get_tree().paused = true
	_root.visible = true
	_apply_mouse_mode()


func _resume() -> void:
	Session.set_paused(false)
	get_tree().paused = false
	_root.visible = false
	_apply_mouse_mode()


func _restart() -> void:
	Session.set_paused(false)
	get_tree().paused = false
	Session.start_run(Session.mode.id)
	get_tree().reload_current_scene()


func _menu() -> void:
	Session.set_paused(false)
	get_tree().paused = false
	_apply_mouse_mode(true)
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _apply_mouse_mode(in_menu: bool = false) -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = PlayerController.gameplay_mouse_mode(get_tree().paused, in_menu)


func _settings() -> void:
	Sfx.play("ui_click")
	var panel := _root.find_child("Settings", true, false) as SettingsPanel
	if panel:
		panel.visible = not panel.visible


func _btn(parent: Control, text: String, cb: Callable) -> void:
	var button := ThemeUtil.menu_button(text)
	button.pressed.connect(func() -> void:
		Sfx.play("ui_click")
		cb.call()
	)
	parent.add_child(button)
