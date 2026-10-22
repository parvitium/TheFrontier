extends Node

## Authority for run rules. Presentation and input emit commands into this node.
## Session owns economy, placement, win eval, wave counters, core/player HP,
## building HP, weapon ammo, and combat resolution (hitscan / turret / trap).
## Views listen to GameBus. A later networked host can own this same API.
##
## Pause: `set_paused(true)` freezes `tick` (rest, respawn, fire/turret
## cooldowns, reload). PauseMenu also pauses the scene tree so views stop.
## That is a full sim halt, not a HUD-only overlay.

const TURRET_INTERVAL := 0.4
const TURRET_DAMAGE := 15.0
const TRAP_DPS := 8.0

var state: GameState = GameState.new()
var mode: GameModeDef = ModeCatalog.by_id(Ids.MODE_SURVIVE)
var selected_mode_id: String = Ids.MODE_SURVIVE
var last_outcome: int = WinEvaluator.Outcome.NONE
var last_stats: Dictionary = {}
var sim_paused: bool = false


func start_run(mode_id: String = "") -> void:
	if mode_id != "":
		selected_mode_id = mode_id
	mode = ModeCatalog.by_id(selected_mode_id)
	state = GameState.new()
	state.begin(mode)
	last_outcome = WinEvaluator.Outcome.NONE
	last_stats = {}
	sim_paused = false
	GameBus.run_started.emit(mode.id)
	GameBus.phase_changed.emit(state.phase)
	GameBus.resources_changed.emit(state.resources.duplicate())
	GameBus.core_health_changed.emit(state.core_health, state.core_max_health)
	GameBus.player_health_changed.emit(state.player_health, state.player_max_health)
	GameBus.ammo_changed.emit()
	GameBus.banner.emit("Rest phase — fortify the core.")


func set_paused(on: bool) -> void:
	sim_paused = on


func tick(delta: float) -> void:
	if sim_paused or not state.is_running():
		return
	state.elapsed_time += delta
	state.fire_cooldown = max(0.0, state.fire_cooldown - delta)
	var turret_keys: Array = state.turret_cooldown.keys()
	for serial in turret_keys:
		state.turret_cooldown[serial] = maxf(0.0, float(state.turret_cooldown[serial]) - delta)
	if state.reload_remaining > 0.0:
		state.reload_remaining = max(0.0, state.reload_remaining - delta)
		if state.reload_remaining <= 0.0:
			_finish_reload()
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
	_register_building(serial, def)
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
	_forget_building(serial)
	state.resources = Economy.add(state.resources, refund)
	GameBus.resources_changed.emit(state.resources.duplicate())
	GameBus.building_destroyed.emit(building_id, serial)
	GameBus.nav_dirty.emit()
	return {ok = true, reason = "", building_id = building_id, origin = origin, refund = refund, serial = serial}


func cmd_building_destroyed(serial: int) -> void:
	var building_id := state.building_id_of(serial)
	if building_id == "":
		return
	if building_id == Ids.ESCAPE_SHIP:
		state.escape_ship_built = false
	_forget_building(serial)
	state.buildings_destroyed += 1
	GameBus.building_destroyed.emit(building_id, serial)
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


func cmd_damage_building(serial: int, amount: float) -> Dictionary:
	if not state.is_running() or not state.building_hp.has(serial) or amount <= 0.0:
		return {ok = false, died = false, hp = 0.0}
	var hp := maxf(0.0, float(state.building_hp[serial]) - amount)
	state.building_hp[serial] = hp
	var maximum := float(state.building_max_hp.get(serial, hp))
	GameBus.building_health_changed.emit(serial, hp, maximum)
	if hp <= 0.0:
		cmd_building_destroyed(serial)
		return {ok = true, died = true, hp = 0.0}
	return {ok = true, died = false, hp = hp}


func cmd_heal_building(serial: int, amount: float) -> bool:
	if not state.is_running() or not state.building_hp.has(serial) or amount <= 0.0:
		return false
	var maximum := float(state.building_max_hp.get(serial, 0.0))
	var hp := minf(maximum, float(state.building_hp[serial]) + amount)
	state.building_hp[serial] = hp
	GameBus.building_health_changed.emit(serial, hp, maximum)
	return true


func cmd_apply_damage(source: String, kind: String, id: Variant, amount: float) -> Dictionary:
	if not state.is_running() or amount <= 0.0:
		return {ok = false, reason = "inactive"}
	if source == "player" and kind == "building":
		return {ok = false, reason = "friendly"}
	if kind == "building":
		return cmd_damage_building(int(id), amount)
	if kind == "core":
		if source == "player" or source == "turret" or source == "trap":
			return {ok = false, reason = "friendly"}
		cmd_damage_core(amount)
		return {ok = true, reason = ""}
	if kind == "player":
		if source == "player":
			return {ok = false, reason = "friendly"}
		cmd_damage_player(amount)
		return {ok = true, reason = ""}
	return {ok = false, reason = "unknown"}


func cmd_resolve_hit(source: String, target: Object, amount: float) -> bool:
	if not state.is_running() or amount <= 0.0 or target == null or not target is Node:
		return false
	var node := target as Node
	if node.is_in_group("player"):
		return cmd_apply_damage(source, "player", 0, amount).ok
	if node.is_in_group("core"):
		return cmd_apply_damage(source, "core", 0, amount).ok
	if node.is_in_group("buildings") or node is BuildingBase:
		var serial := _serial_of(node)
		if serial < 0:
			return false
		return cmd_apply_damage(source, "building", serial, amount).ok
	if node.is_in_group("mobs"):
		return cmd_damage_mob(node, amount)
	return false


func cmd_damage_mob(target: Node, amount: float) -> bool:
	if target == null or not state.is_running() or amount <= 0.0:
		return false
	var health := target.get_node_or_null("Health") as Health
	if health == null:
		return false
	health.apply(amount, null)
	return true


func cmd_try_turret_fire(serial: int, target: Node, damage: float = TURRET_DAMAGE, interval: float = TURRET_INTERVAL) -> bool:
	if not state.is_running():
		return false
	if not state.building_hp.has(serial) or float(state.building_hp[serial]) <= 0.0:
		return false
	if float(state.turret_cooldown.get(serial, 0.0)) > 0.0:
		return false
	if target == null:
		return false
	state.turret_cooldown[serial] = interval
	return cmd_resolve_hit("turret", target, damage)


func cmd_trap_pulse(serial: int, target: Node, delta: float, dps: float = TRAP_DPS) -> bool:
	if not state.is_running() or delta <= 0.0:
		return false
	if not state.building_hp.has(serial) or float(state.building_hp[serial]) <= 0.0:
		return false
	return cmd_resolve_hit("trap", target, dps * delta)


func cmd_select_weapon(i: int) -> bool:
	if i < 0 or i >= state.weapons.size():
		return false
	state.selected_weapon = i
	state.reload_remaining = 0.0
	GameBus.ammo_changed.emit()
	return true


func cmd_try_fire() -> Dictionary:
	if not state.is_running() or not state.player_alive:
		return {ok = false, reason = "Cannot fire."}
	if state.reload_remaining > 0.0:
		return {ok = false, reason = "Reloading."}
	if state.fire_cooldown > 0.0:
		return {ok = false, reason = "Cooldown."}
	if state.weapons.is_empty():
		return {ok = false, reason = "No weapon."}
	var pack: Dictionary = state.weapons[state.selected_weapon]
	var def := WeaponCatalog.by_id(str(pack.id))
	if def == null:
		return {ok = false, reason = "Unknown weapon."}
	if int(pack.mag) <= 0:
		cmd_start_reload()
		return {ok = false, reason = "Empty magazine."}
	pack.mag = int(pack.mag) - 1
	state.weapons[state.selected_weapon] = pack
	state.fire_cooldown = def.fire_interval
	GameBus.ammo_changed.emit()
	return {
		ok = true,
		reason = "",
		damage = def.damage,
		pellets = def.pellets,
		spread = def.spread_degrees,
		range = def.range,
		weapon_id = def.id,
	}


func cmd_start_reload() -> bool:
	if not state.is_running() or not state.player_alive:
		return false
	if state.reload_remaining > 0.0 or state.weapons.is_empty():
		return false
	var pack: Dictionary = state.weapons[state.selected_weapon]
	var def := WeaponCatalog.by_id(str(pack.id))
	if def == null:
		return false
	if int(pack.mag) >= def.magazine_size or int(pack.reserve) <= 0:
		return false
	state.reload_remaining = def.reload_time
	GameBus.ammo_changed.emit()
	return true


func current_weapon_def() -> WeaponDef:
	if state.weapons.is_empty():
		return null
	return WeaponCatalog.by_id(str(state.weapons[state.selected_weapon].id))


func ammo_text() -> String:
	if state.reload_remaining > 0.0:
		return "RELOADING"
	if state.weapons.is_empty():
		return ""
	var pack: Dictionary = state.weapons[state.selected_weapon]
	return "%d / %d" % [int(pack.mag), int(pack.reserve)]


func cmd_collect_relic() -> void:
	if not state.is_running():
		return
	state.relics_collected += 1
	state.score += 50
	GameBus.relic_collected.emit(state.relics_collected, mode.gather_count)
	if mode.gather_count > 0:
		GameBus.banner.emit("Relic recovered (%d/%d)." % [state.relics_collected, mode.gather_count])
	else:
		GameBus.banner.emit("Relic recovered. Score +50.")
	_evaluate()


func cmd_mark_escape_built() -> void:
	if not state.is_running():
		return
	if mode.kind != GameModeDef.Kind.ESCAPE:
		return
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


func _register_building(serial: int, def: BuildingDef) -> void:
	state.building_hp[serial] = def.max_health
	state.building_max_hp[serial] = def.max_health
	state.turret_cooldown[serial] = 0.0
	GameBus.building_health_changed.emit(serial, def.max_health, def.max_health)


func _forget_building(serial: int) -> void:
	state.free_serial(serial)
	state.building_hp.erase(serial)
	state.building_max_hp.erase(serial)
	state.turret_cooldown.erase(serial)


func _serial_of(node: Node) -> int:
	if node is BuildingBase:
		return (node as BuildingBase).serial
	if node.has_meta("building_serial"):
		return int(node.get_meta("building_serial"))
	return -1


func _finish_reload() -> void:
	if state.weapons.is_empty():
		return
	var pack: Dictionary = state.weapons[state.selected_weapon]
	var def := WeaponCatalog.by_id(str(pack.id))
	if def == null:
		return
	var need: int = def.magazine_size - int(pack.mag)
	var take: int = mini(need, int(pack.reserve))
	pack.mag = int(pack.mag) + take
	pack.reserve = int(pack.reserve) - take
	state.weapons[state.selected_weapon] = pack
	GameBus.ammo_changed.emit()


func _restock_ammo() -> void:
	for i in state.weapons.size():
		var pack: Dictionary = state.weapons[i]
		var def := WeaponCatalog.by_id(str(pack.id))
		if def == null:
			continue
		var missing: int = def.reserve - int(pack.reserve)
		if missing > 0:
			pack.reserve = int(pack.reserve) + maxi(1, int(ceil(float(missing) * 0.35)))
			state.weapons[i] = pack
	GameBus.ammo_changed.emit()
	GameBus.restock_ammo.emit()


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
	_restock_ammo()
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
