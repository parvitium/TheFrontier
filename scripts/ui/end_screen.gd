class_name EndScreen
extends CanvasLayer

var _root: Control
var _title: Label
var _stats: Label


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.04, 0.72)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(420, 0)
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 34)
	box.add_child(_title)
	_stats = Label.new()
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats.add_theme_font_size_override("font_size", 16)
	box.add_child(_stats)
	_btn(box, "Restart mode", _restart)
	_btn(box, "Main menu", _menu)
	GameBus.run_ended.connect(_on_ended)


func _on_ended(outcome: int, stats: Dictionary) -> void:
	Session.set_paused(true)
	get_tree().paused = true
	_root.visible = true
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if outcome == WinEvaluator.Outcome.VICTORY:
		_title.text = "EXTRACTED"
		ThemeUtil.font_color(_title, Color(0.4, 0.95, 0.7))
	else:
		_title.text = "CORE LOST"
		ThemeUtil.font_color(_title, Color(0.95, 0.35, 0.28))
	_stats.text = "%s\nTime %.0fs   Waves %d   Kills %d   Score %d" % [
		stats.get("mode_name", ""),
		stats.get("elapsed", 0.0),
		stats.get("waves_completed", 0),
		stats.get("kills", 0),
		stats.get("score", 0),
	]


func _restart() -> void:
	Session.set_paused(false)
	get_tree().paused = false
	Session.start_run(Session.mode.id)
	get_tree().reload_current_scene()


func _menu() -> void:
	Session.set_paused(false)
	get_tree().paused = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _btn(parent: Control, text: String, cb: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(cb)
	parent.add_child(button)
