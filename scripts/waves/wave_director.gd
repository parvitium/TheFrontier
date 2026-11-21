class_name WaveDirector
extends Node

var _queue: Array[Dictionary] = []
var _delay: float = 0.0
var _active: bool = false
var _spawn_cursor: int = 0


func _ready() -> void:
	add_to_group("wave_director")
	GameBus.wave_started.connect(_on_wave_started)
	GameBus.phase_changed.connect(_on_phase)


func _physics_process(delta: float) -> void:
	if not _active or _queue.is_empty():
		return
	_delay -= delta
	if _delay > 0.0:
		return
	var item: Dictionary = _queue.pop_front()
	_spawn(item)
	if _queue.is_empty():
		_delay = 0.0
	else:
		_delay = float(_queue[0].delay)


func _on_wave_started(_index: int) -> void:
	var spec := Session.current_wave_spec()
	_queue.clear()
	_spawn_cursor = 0
	for entry in spec.entries:
		for _i in entry.count:
			_queue.append({
				"mob_id": entry.mob_id,
				"delay": entry.spawn_delay,
				"prefer_core": entry.prefer_core,
				"hp": spec.hp_multiplier,
				"dmg": spec.damage_multiplier,
			})
	_active = true
	_delay = 0.15


func _on_phase(phase: int) -> void:
	if phase != GameState.Phase.WAVE:
		_active = false
		_queue.clear()


func _spawn(item: Dictionary) -> void:
	var def := MobCatalog.by_id(str(item.mob_id))
	if def == null:
		return
	var mob := MobActor.new()
	mob.name = "%s_%d" % [def.id, Session.state.mobs_spawned_this_wave]
	if bool(item.prefer_core):
		def.target_bias = MobDef.TargetBias.CORE
	mob.configure(def, float(item.hp), float(item.dmg))
	mob.global_position = next_spawn_point()
	var arena := get_parent()
	arena.add_child(mob)
	Session.cmd_mob_spawned()


func next_spawn_point() -> Vector3:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var player_pos := Vector3.ZERO
	if player:
		player_pos = player.global_position
	var chosen: Vector3 = SpawnRules.pick(_candidate_positions(), player_pos, Landscape.colliding_cover_positions(), _spawn_cursor)
	_spawn_cursor += 1
	return _snap_nav(Landscape.seat(chosen, 0.2))


func _candidate_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	var holder := get_parent().get_node_or_null("SpawnPoints")
	if holder == null:
		return SpawnRules.ring_points()
	for child in holder.get_children():
		if child is Node3D:
			out.append((child as Node3D).global_position)
	if out.is_empty():
		return SpawnRules.ring_points()
	return out


func _snap_nav(pos: Vector3) -> Vector3:
	var maps := NavigationServer3D.get_maps()
	if maps.is_empty():
		return pos
	var closest: Vector3 = NavigationServer3D.map_get_closest_point(maps[0], pos)
	var d: float = closest.distance_to(pos)
	if d > 0.05 and d < 8.0:
		return closest + Vector3(0.0, 0.05, 0.0)
	return pos
