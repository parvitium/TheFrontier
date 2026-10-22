extends Node

## Usage: godot --path . --scene res://tools/capture.tscn -- --shot=menu --out=user://shot.png --wait=1.2

var _shot: String = "menu"
var _out: String = "user://shot.png"
var _wait: float = 1.25
var _elapsed: float = 0.0
var _done: bool = false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot = arg.substr(7)
		elif arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--wait="):
			_wait = maxf(0.4, float(arg.substr(7)))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(Vector2i(1280, 720))
	if _shot.begins_with("menu"):
		var menu: Node = load("res://scenes/ui/main_menu.tscn").instantiate()
		add_child(menu)
		await get_tree().process_frame
		if menu is MainMenu:
			var mm := menu as MainMenu
			if _shot == "menu_play":
				mm._show_play()
			elif _shot == "menu_settings":
				mm._show_settings()
			elif _shot == "menu_credits":
				mm._show_credits()
	else:
		Session.selected_mode_id = Ids.MODE_SURVIVE
		Session.start_run(Ids.MODE_SURVIVE)
		var arena: Node = load("res://scenes/world/arena.tscn").instantiate()
		add_child(arena)


func _process(delta: float) -> void:
	if _done:
		return
	_elapsed += delta
	if _elapsed < _wait:
		return
	_done = true
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png(_out)
		print("CAPTURE OK ", _out, " ", img.get_width(), "x", img.get_height())
	else:
		print("CAPTURE FAIL no image")
	get_tree().quit(0)
