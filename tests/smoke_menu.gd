extends Node

## Boots the main menu for real wall-clock seconds.
## Usage: godot --headless --path . --scene res://tests/smoke_menu.tscn -- --seconds=2

var _seconds: float = 2.0
var _wall_start: int = 0
var _finished: bool = false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seconds="):
			_seconds = maxf(1.0, float(arg.substr(10)))
	process_mode = Node.PROCESS_MODE_ALWAYS
	_wall_start = Time.get_ticks_msec()
	var menu: Node = load("res://scenes/ui/main_menu.tscn").instantiate()
	add_child(menu)


func _process(_delta: float) -> void:
	if _finished:
		return
	var wall := float(Time.get_ticks_msec() - _wall_start) / 1000.0
	if wall < _seconds:
		return
	_finished = true
	if get_child_count() == 0:
		print("MENU SMOKE FAIL missing menu scene")
		get_tree().quit(1)
		return
	print("MENU SMOKE OK wall>=%.1fs scene=%s" % [_seconds, get_child(0).name])
	get_tree().quit(0)
