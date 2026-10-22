extends Node

## Authority for run rules. Presentation and input emit commands into this node.
## Keep this separable from views so a later networked host can own the same API.

var state: GameState = GameState.new()
var mode: GameModeDef = ModeCatalog.by_id(Ids.MODE_SURVIVE)
var selected_mode_id: String = Ids.MODE_SURVIVE
var last_outcome: int = WinEvaluator.Outcome.NONE
var last_stats: Dictionary = {}


func start_run(mode_id: String = "") -> void:
	if mode_id != "":
		selected_mode_id = mode_id
	mode = ModeCatalog.by_id(selected_mode_id)
	state = GameState.new()
	state.begin(mode)
	last_outcome = WinEvaluator.Outcome.NONE
	last_stats = {}
	GameBus.run_started.emit(mode.id)
	GameBus.phase_changed.emit(state.phase)
	GameBus.resources_changed.emit(state.resources.duplicate())
	GameBus.core_health_changed.emit(state.core_health, state.core_max_health)
	GameBus.player_health_changed.emit(state.player_health, state.player_max_health)
	GameBus.banner.emit("Rest phase — fortify the core.")


func tick(delta: float) -> void:
	if not state.is_running():
		return
	state.elapsed_time += delta
	if not state.player_alive:
		state.respawn_in = max(0.0, state.respawn_in - delta)
		if state.respawn_in <= 0.0 and state.core_health > 0.0:
			_respawn_player()
	if state.phase == GameState.Phase.REST:
		state.rest_remaining = max(0.0, state.rest_remaining - delta)
		if state.rest_remaining <= 0.0:
			_begin_wave()
	_evaluate()


func cmd_gather(resource_type: String, amount: int) -> bool:
	if not state.is_running() or amount <= 0:
		return false
	var gain := Economy.empty_wallet()
	gain[resource_type] = amount
	state.resources = Economy.add(state.resources, gain)
	GameBus.resources_changed.emit(state.resources.duplicate())
	return true


func cmd_try_place(building_id: String, origin: Vector2i) -> Dictionary:
	var def := BuildingCatalog.by_id(building_id)
	if def == null or not state.is_running():
		return {ok = false, reason = "Cannot build now."}
	if not _building_allowed(def):
		return {ok = false, reason = "Not available in this mode."}
	var placement := PlacementRules.evaluate(state.occupied_cells, building_id, origin)
	if not placement.ok:
		return placement
	if not Economy.can_afford(state.resources, def.cost()):
		return {ok = false, reason = "Not enough resources."}
	state.resources = Economy.spend(state.resources, def.cost())
	var cells: Array[Vector2i] = []
	for cell: Vector2i in placement.cells:
		cells.append(cell)
	var serial: int = state.occupy(cells, building_id)
	GameBus.resources_changed.emit(state.resources.duplicate())
	GameBus.building_placed.emit(building_id, origin)
	if building_id == Ids.ESCAPE_SHIP:
		cmd_mark_escape_built()
	if def.blocks_navigation:
		GameBus.nav_dirty.emit()
	return {ok = true, reason = "", cells = placement.cells, def = def, serial = serial}


func cmd_dismantle_at(origin: Vector2i) -> Dictionary:
	if not state.is_running():
		return {ok = false, reason = "No active run."}
	var serial := state.serial_at(origin)
	if serial < 0:
		return {ok = false, reason = "Nothing to dismantle."}
	var building_id := state.building_id_of(serial)
	var def := BuildingCatalog.by_id(building_id)
	var refund := Economy.refund(def.cost() if def else Economy.empty_wallet(), 0.5)
	if building_id == Ids.ESCAPE_SHIP:
		state.escape_ship_built = false
	state.free_serial(serial)
	state.resources = Economy.add(state.resources, refund)
	GameBus.resources_changed.emit(state.resources.duplicate())
	GameBus.building_destroyed.emit(building_id)
	GameBus.nav_dirty.emit()
	return {ok = true, reason = "", building_id = building_id, origin = origin, refund = refund, serial = serial}


func cmd_building_destroyed(serial: int) -> void:
	var building_id := state.free_serial(serial)
	if building_id == "":
		return
	if building_id == Ids.ESCAPE_SHIP:
		state.escape_ship_built = false
	state.buildings_destroyed += 1
	GameBus.building_destroyed.emit(building_id)
	GameBus.nav_dirty.emit()


func cmd_damage_core(amount: float) -> void:
	if not state.is_running():
		return
	state.core_health = max(0.0, state.core_health - amount)
	GameBus.core_health_changed.emit(state.core_health, state.core_max_health)
	_evaluate()


func cmd_heal_core(amount: float) -> void:
	if not state.is_running():
		return
	state.core_health = min(state.core_max_health, state.core_health + amount)
	GameBus.core_health_changed.emit(state.core_health, state.core_max_health)


func cmd_damage_player(amount: float) -> void:
	if not state.is_running() or not state.player_alive:
		return
	state.player_health = max(0.0, state.player_health - amount)
	GameBus.player_health_changed.emit(state.player_health, state.player_max_health)
	if state.player_health <= 0.0:
		state.player_alive = false
		state.respawn_in = mode.player_respawn_seconds
		state.resources = Economy.tax(state.resources, mode.death_scrap_tax_ratio)
		GameBus.resources_changed.emit(state.resources.duplicate())
		GameBus.player_died.emit()
		GameBus.banner.emit("You are down. Respawn in %.0fs." % state.respawn_in)


func cmd_heal_player(amount: float) -> void:
	if not state.player_alive:
		return
	state.player_health = min(state.player_max_health, state.player_health + amount)
	GameBus.player_health_changed.emit(state.player_health, state.player_max_health)


func cmd_collect_relic() -> void:
	if not state.is_running():
		return
	state.relics_collected += 1
	state.score += 50
	GameBus.relic_collected.emit(state.relics_collected, mode.gather_count)
	GameBus.banner.emit("Relic recovered (%d/%d)." % [state.relics_collected, mode.gather_count])
	_evaluate()


func cmd_mark_escape_built() -> void:
	state.escape_ship_built = true
	GameBus.banner.emit("Escape ship assembled.")
	_evaluate()


func cmd_mob_spawned() -> void:
	state.mobs_alive += 1
	state.mobs_spawned_this_wave += 1


func cmd_mob_killed(mob_id: String) -> void:
	state.mobs_alive = max(0, state.mobs_alive - 1)
	state.kills += 1
	state.score += 10
	GameBus.mob_killed.emit(mob_id)
	if state.phase == GameState.Phase.WAVE and state.mobs_alive <= 0 and state.mobs_spawned_this_wave >= state.mobs_to_spawn_this_wave:
		_clear_wave()


func cmd_add_score(amount: int) -> void:
	state.score += amount


func current_wave_spec() -> WaveSpec:
	return WaveCatalog.wave_for(state.wave_index, mode.kind == GameModeDef.Kind.ENDLESS)


func _building_allowed(def: BuildingDef) -> bool:
	if def.buildable_in_all_modes:
		return true
	return mode.kind == GameModeDef.Kind.ESCAPE and def.id == mode.escape_building_id


func _begin_wave() -> void:
	state.wave_index += 1
	state.phase = GameState.Phase.WAVE
	state.mobs_alive = 0
	state.mobs_spawned_this_wave = 0
	var spec := current_wave_spec()
	state.mobs_to_spawn_this_wave = spec.total_mobs()
	GameBus.phase_changed.emit(state.phase)
	GameBus.wave_started.emit(state.wave_index)
	GameBus.banner.emit("Wave %d incoming." % state.wave_index)


func _clear_wave() -> void:
	state.waves_completed += 1
	state.score += 25
	GameBus.wave_cleared.emit(state.wave_index)
	if _evaluate():
		return
	state.phase = GameState.Phase.REST
	state.rest_remaining = mode.rest_seconds
	GameBus.phase_changed.emit(state.phase)
	GameBus.restock_ammo.emit()
	GameBus.banner.emit("Wave cleared. Rest %.0fs." % state.rest_remaining)


func _respawn_player() -> void:
	state.player_alive = true
	state.player_health = state.player_max_health
	state.respawn_in = 0.0
	GameBus.player_health_changed.emit(state.player_health, state.player_max_health)
	GameBus.player_respawned.emit()
	GameBus.banner.emit("Back on your feet. The core still stands.")


func _evaluate() -> bool:
	var outcome := WinEvaluator.evaluate(state, mode)
	if outcome == WinEvaluator.Outcome.NONE or not state.is_running():
		return outcome != WinEvaluator.Outcome.NONE
	state.phase = GameState.Phase.VICTORY if outcome == WinEvaluator.Outcome.VICTORY else GameState.Phase.DEFEAT
	last_outcome = outcome
	last_stats = snapshot()
	GameBus.phase_changed.emit(state.phase)
	GameBus.run_ended.emit(outcome, last_stats)
	return true


func snapshot() -> Dictionary:
	return {
		"mode_id": mode.id,
		"mode_name": mode.display_name,
		"outcome": last_outcome,
		"elapsed": state.elapsed_time,
		"waves_completed": state.waves_completed,
		"kills": state.kills,
		"score": state.score,
		"relics": state.relics_collected,
		"core_health": state.core_health,
	}
