extends Node

## Boots the arena for real wall-clock seconds and checks the sim ticked.
## Usage: godot --headless --path . --scene res://tests/smoke_arena.tscn -- --mode=survive --seconds=3

var _mode: String = Ids.MODE_SURVIVE
var _seconds: float = 3.0
var _wall_start: int = 0
var _finished: bool = false


func _ready() -> void:
	_parse_args()
	process_mode = Node.PROCESS_MODE_ALWAYS
	Session.set_paused(false)
	Session.selected_mode_id = _mode
	Session.start_run(_mode)
	_wall_start = Time.get_ticks_msec()
	var arena: Node = load("res://scenes/world/arena.tscn").instantiate()
	add_child(arena)


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			_mode = arg.substr(7)
		elif arg.begins_with("--seconds="):
			_seconds = maxf(1.0, float(arg.substr(10)))


func _process(_delta: float) -> void:
	if _finished:
		return
	var wall := float(Time.get_ticks_msec() - _wall_start) / 1000.0
	if wall > 20.0:
		_fail("timed out waiting for smoke window")
		return
	if wall < _seconds:
		return
	_check()


func _check() -> void:
	_finished = true
	var arena := get_node_or_null("Arena")
	if arena == null:
		_fail("arena scene missing")
		return
	var required := ["Core", "Player", "WaveDirector", "HUD", "PauseMenu", "EndScreen"]
	for name in required:
		if arena.get_node_or_null(name) == null:
			_fail("missing node %s" % name)
			return
	if get_tree().get_nodes_in_group("resource_nodes").is_empty():
		_fail("no resource nodes")
		return
	if Session.mode.relics_on_map > 0 and get_tree().get_nodes_in_group("relics").is_empty():
		_fail("expected relics for mode %s" % _mode)
		return
	if Session.state.elapsed_time < minf(1.0, _seconds * 0.4):
		_fail("sim did not tick (elapsed=%.2f)" % Session.state.elapsed_time)
		return
	print("SMOKE OK mode=%s wall>=%.1fs sim=%.2fs relics=%d" % [_mode, _seconds, Session.state.elapsed_time, get_tree().get_nodes_in_group("relics").size()])
	get_tree().quit(0)


func _fail(reason: String) -> void:
	_finished = true
	push_error("SMOKE FAIL %s" % reason)
	print("SMOKE FAIL ", reason)
	get_tree().quit(1)
