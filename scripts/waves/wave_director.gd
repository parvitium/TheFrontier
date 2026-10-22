class_name WaveDirector
extends Node

var _queue: Array[Dictionary] = []
var _delay: float = 0.0
var _active: bool = false


func _ready() -> void:
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
	mob.global_position = _spawn_point()
	var arena := get_parent()
	arena.add_child(mob)
	Session.cmd_mob_spawned()


func _spawn_point() -> Vector3:
	var holder := get_parent().get_node_or_null("SpawnPoints")
	if holder == null or holder.get_child_count() == 0:
		return Vector3(28, 0.2, 0)
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var best: Node3D = holder.get_child(0)
	var best_d := -1.0
	for child in holder.get_children():
		if child is Node3D:
			var d := 0.0
			if player:
				d = (child as Node3D).global_position.distance_to(player.global_position)
			if d > best_d:
				best_d = d
				best = child
	return best.global_position + Vector3(0, 0.15, 0)
