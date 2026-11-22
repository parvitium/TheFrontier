extends Node

## Boots the arena for real wall-clock seconds and checks the sim ticked.
## Spawns one live MobActor and verifies it moves and takes Session damage.
## Usage: godot --headless --path . --scene res://tests/smoke_arena.tscn -- --mode=survive --seconds=3

var _mode: String = Ids.MODE_SURVIVE
var _seconds: float = 3.0
var _wall_start: int = 0
var _finished: bool = false
var _probe: MobActor
var _probe_start: Vector3 = Vector3.ZERO
var _probe_ready: bool = false


func _ready() -> void:
	_parse_args()
	process_mode = Node.PROCESS_MODE_ALWAYS
	Session.set_paused(false)
	Session.selected_mode_id = _mode
	Session.start_run(_mode)
	_wall_start = Time.get_ticks_msec()
	var boot := Time.get_ticks_msec()
	var arena: Node = load("res://scenes/world/arena.tscn").instantiate()
	add_child(arena)
	print("ARENA INSTANTIATE_MS=", Time.get_ticks_msec() - boot)
	call_deferred("_spawn_probe_mob")


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			_mode = arg.substr(7)
		elif arg.begins_with("--seconds="):
			_seconds = maxf(1.0, float(arg.substr(10)))


func _spawn_probe_mob() -> void:
	var arena := get_node_or_null("Arena")
	if arena == null:
		return
	var def := MobCatalog.by_id(Ids.RUSHER)
	if def == null:
		return
	var mob := MobActor.new()
	mob.name = "SmokeProbeMob"
	mob.configure(def)
	arena.add_child(mob)
	mob.global_position = Landscape.seat(Vector3(12, 0, 0), 0.2)
	Session.cmd_mob_spawned()
	_probe = mob
	await get_tree().physics_frame
	await get_tree().physics_frame
	if is_instance_valid(mob):
		_probe_start = mob.global_position
		_probe_ready = true


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
	if not _probe_ready or not is_instance_valid(_probe):
		_fail("live MobActor missing")
		return
	var traveled := _probe.global_position.distance_to(_probe_start)
	if traveled < 0.25:
		_fail("MobActor did not move (d=%.2f)" % traveled)
		return
	var health := _probe.get_node_or_null("Health") as Health
	if health == null:
		_fail("MobActor has no Health")
		return
	var before := health.current
	if not Session.cmd_damage_mob(_probe, 12.0):
		_fail("cmd_damage_mob rejected live MobActor")
		return
	if health.current >= before:
		_fail("MobActor HP unchanged after Session damage")
		return
	if not _fire_player_shot_at_probe(arena):
		return
	print("SMOKE OK mode=%s wall>=%.1fs sim=%.2fs relics=%d mob_move=%.2f mob_hp=%.1f" % [_mode, _seconds, Session.state.elapsed_time, get_tree().get_nodes_in_group("relics").size(), traveled, health.current])
	get_tree().quit(0)


func _fire_player_shot_at_probe(arena: Node) -> bool:
	var player := arena.get_node_or_null("Player") as CharacterBody3D
	if player == null or not is_instance_valid(_probe):
		_fail("player-shot path missing player or mob")
		return false
	var cam := player.get_node_or_null("Camera3D") as Camera3D
	if cam == null:
		_fail("player-shot path missing camera")
		return false
	var forward := -cam.global_transform.basis.z
	_probe.global_position = Landscape.seat(player.global_position + forward * 4.5, 0.2)
	var origin := cam.global_position
	var muzzle := origin + forward * 0.6
	var hit: Dictionary = Hitscan.query(cam.get_world_3d(), origin, forward, 40.0, [player.get_rid()])
	var dest: Vector3 = _probe.global_position + Vector3(0.0, 1.0, 0.0)
	var collider: Object = _probe
	var normal := Vector3.UP
	if bool(hit.get("hit", false)):
		dest = hit.position
		collider = hit.get("collider", _probe)
		normal = hit.get("normal", Vector3.UP)
	CombatFx.muzzle_flash(player, muzzle, Color(1.0, 0.78, 0.34), "kinetic", forward)
	CombatFx.tracer(arena, muzzle, dest, Color(1.0, 0.78, 0.34), "kinetic")
	CombatFx.impact(arena, dest, Color(1.0, 0.78, 0.34), collider, normal)
	if collider is Node:
		Session.cmd_resolve_hit("player", collider, 11.0)
	var pool := CombatFx.pool_for(arena)
	if pool == null:
		_fail("combat FX pool missing after player shot")
		return false
	if pool.max_particle_amount() > CombatFx.CAP_EXPLODE:
		_fail("player-shot FX exceeded particle cap")
		return false
	if not is_instance_valid(arena):
		_fail("player-shot-on-mob freed the arena")
		return false
	return true


func _fail(reason: String) -> void:
	_finished = true
	push_error("SMOKE FAIL %s" % reason)
	print("SMOKE FAIL ", reason)
	get_tree().quit(1)
