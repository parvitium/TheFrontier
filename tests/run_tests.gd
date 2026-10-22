extends SceneTree

var _failed: int = 0
var _passed: int = 0


func _init() -> void:
	print("TheFrontier headless tests")
	_economy()
	_building_costs()
	_placement()
	_wave_scaling()
	_win_conditions()
	_session_flow()
	_death_and_respawn()
	print("Passed: %d  Failed: %d" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _ok(cond: bool, name: String) -> void:
	if cond:
		_passed += 1
		print("  PASS  ", name)
	else:
		_failed += 1
		print("  FAIL  ", name)


func _economy() -> void:
	print("economy")
	var wallet := {Ids.SCRAP: 20, Ids.CRYSTAL: 5}
	_ok(Economy.can_afford(wallet, {Ids.SCRAP: 8, Ids.CRYSTAL: 0}), "afford wall")
	_ok(not Economy.can_afford(wallet, {Ids.SCRAP: 25, Ids.CRYSTAL: 10}), "reject turret")
	var spent := Economy.spend(wallet, {Ids.SCRAP: 8, Ids.CRYSTAL: 0})
	_ok(spent[Ids.SCRAP] == 12 and spent[Ids.CRYSTAL] == 5, "spend scrap")
	var blocked := Economy.spend(wallet, {Ids.SCRAP: 99, Ids.CRYSTAL: 0})
	_ok(blocked[Ids.SCRAP] == 20, "spend rejected keeps wallet")
	var added := Economy.add(wallet, {Ids.SCRAP: 3, Ids.CRYSTAL: 2})
	_ok(added[Ids.SCRAP] == 23 and added[Ids.CRYSTAL] == 7, "add loot")
	var taxed := Economy.tax({Ids.SCRAP: 20, Ids.CRYSTAL: 10}, 0.15)
	_ok(taxed[Ids.SCRAP] == 17 and taxed[Ids.CRYSTAL] == 10, "death tax scrap only")
	var refund := Economy.refund({Ids.SCRAP: 25, Ids.CRYSTAL: 10}, 0.5)
	_ok(refund[Ids.SCRAP] == 12 and refund[Ids.CRYSTAL] == 5, "half refund")


	_ok((Hitscan.HOSTILE_MASK & 32) == 0, "player shots ignore core layer")
	_ok((Hitscan.HOSTILE_MASK & 4) != 0, "player shots hit mobs")


func _building_costs() -> void:
	print("building costs")
	_ok(BuildingCatalog.by_id(Ids.WALL).scrap_cost == 8, "wall cost")
	_ok(BuildingCatalog.by_id(Ids.TURRET).crystal_cost == 10, "turret crystal")
	_ok(BuildingCatalog.by_id(Ids.TRAP).scrap_cost == 12, "trap cost")
	_ok(BuildingCatalog.by_id(Ids.REPAIR).crystal_cost == 15, "repair cost")
	_ok(BuildingCatalog.by_id(Ids.ESCAPE_SHIP).footprint == Vector2i(2, 2), "ship footprint")
	var escape := ModeCatalog.by_id(Ids.MODE_ESCAPE)
	var survive := ModeCatalog.by_id(Ids.MODE_SURVIVE)
	_ok(BuildingCatalog.available_for_mode(escape).size() == 5, "escape offers ship")
	_ok(BuildingCatalog.available_for_mode(survive).size() == 4, "survive hides ship")


func _placement() -> void:
	print("placement")
	var occupied := {}
	var ok := PlacementRules.evaluate(occupied, Ids.WALL, Vector2i(4, 4))
	_ok(ok.ok, "open cell valid")
	var core := PlacementRules.evaluate(occupied, Ids.WALL, Vector2i(0, 0))
	_ok(not core.ok, "core cell blocked")
	var oob := PlacementRules.evaluate(occupied, Ids.WALL, Vector2i(80, 0))
	_ok(not oob.ok, "out of bounds")
	occupied[Vector2i(4, 4)] = 1
	var overlap := PlacementRules.evaluate(occupied, Ids.WALL, Vector2i(4, 4))
	_ok(not overlap.ok, "overlap blocked")
	var ship := PlacementRules.evaluate({}, Ids.ESCAPE_SHIP, Vector2i(5, 5))
	_ok(ship.ok and ship.cells.size() == 4, "ship uses 4 cells")
	_ok(PlacementRules.world_to_cell(Vector3(4.2, 0, -3.8)) == Vector2i(2, -2), "world to cell snap")


func _wave_scaling() -> void:
	print("wave scaling")
	var w1 := WaveCatalog.wave_for(1, false)
	var w3 := WaveCatalog.wave_for(3, false)
	_ok(w1.total_mobs() == 6, "wave 1 count")
	_ok(w3.total_mobs() == 9, "wave 3 count")
	var e4 := WaveScaler.scale(4)
	var e8 := WaveScaler.scale(8)
	_ok(e8.total_mobs() > e4.total_mobs(), "endless count grows")
	_ok(e8.hp_multiplier > e4.hp_multiplier, "endless hp grows")
	_ok(WaveCatalog.wave_for(10, true).wave_number == 10, "endless uses scaler")


func _win_conditions() -> void:
	print("win conditions")
	var survive := ModeCatalog.by_id(Ids.MODE_SURVIVE)
	var gather := ModeCatalog.by_id(Ids.MODE_GATHER)
	var escape := ModeCatalog.by_id(Ids.MODE_ESCAPE)
	var endless := ModeCatalog.by_id(Ids.MODE_ENDLESS)
	var state := GameState.new()
	state.begin(survive)
	_ok(WinEvaluator.evaluate(state, survive) == WinEvaluator.Outcome.NONE, "survive start none")
	state.waves_completed = 3
	_ok(WinEvaluator.evaluate(state, survive) == WinEvaluator.Outcome.VICTORY, "survive waves")
	state.waves_completed = 0
	var timed: GameModeDef = survive.duplicate()
	timed.survive_waves = 0
	timed.survive_seconds = 120.0
	state.elapsed_time = 120.0
	_ok(WinEvaluator.evaluate(state, timed) == WinEvaluator.Outcome.VICTORY, "survive time")
	state.elapsed_time = 0.0
	state.core_health = 0
	_ok(WinEvaluator.evaluate(state, survive) == WinEvaluator.Outcome.DEFEAT, "core death")
	state = GameState.new()
	state.begin(gather)
	state.relics_collected = 4
	_ok(WinEvaluator.evaluate(state, gather) == WinEvaluator.Outcome.VICTORY, "gather relics")
	state = GameState.new()
	state.begin(escape)
	state.escape_ship_built = true
	_ok(WinEvaluator.evaluate(state, escape) == WinEvaluator.Outcome.VICTORY, "escape ship")
	state = GameState.new()
	state.begin(endless)
	state.waves_completed = 99
	state.elapsed_time = 9999
	_ok(WinEvaluator.evaluate(state, endless) == WinEvaluator.Outcome.NONE, "endless never wins")
	state.core_health = 0
	_ok(WinEvaluator.evaluate(state, endless) == WinEvaluator.Outcome.DEFEAT, "endless can lose")


func _session_flow() -> void:
	print("session flow")
	var mode := ModeCatalog.by_id(Ids.MODE_SURVIVE)
	var state := GameState.new()
	state.begin(mode)
	_ok(state.phase == GameState.Phase.REST, "starts resting")
	_ok(int(state.resources[Ids.SCRAP]) == 45, "survive starting scrap")
	state.wave_index = 1
	state.phase = GameState.Phase.WAVE
	var spec := WaveCatalog.wave_for(state.wave_index, false)
	state.mobs_to_spawn_this_wave = spec.total_mobs()
	_ok(state.mobs_to_spawn_this_wave == 6, "wave 1 spawn count")
	for _i in state.mobs_to_spawn_this_wave:
		state.mobs_alive += 1
		state.mobs_spawned_this_wave += 1
	for _i in state.mobs_to_spawn_this_wave:
		state.mobs_alive -= 1
		state.kills += 1
	if state.mobs_alive <= 0 and state.mobs_spawned_this_wave >= state.mobs_to_spawn_this_wave:
		state.waves_completed += 1
		state.phase = GameState.Phase.REST
	_ok(state.waves_completed == 1, "cleared wave 1")
	_ok(state.phase == GameState.Phase.REST, "back to rest")
	var wall := BuildingCatalog.by_id(Ids.WALL)
	var placement := PlacementRules.evaluate(state.occupied_cells, Ids.WALL, Vector2i(5, 4))
	_ok(placement.ok and Economy.can_afford(state.resources, wall.cost()), "place wall allowed")
	var cells: Array[Vector2i] = []
	for cell: Vector2i in placement.cells:
		cells.append(cell)
	var serial: int = state.occupy(cells, Ids.WALL)
	state.resources = Economy.spend(state.resources, wall.cost())
	_ok(state.serial_at(Vector2i(5, 4)) == serial, "serial stored")
	var again := PlacementRules.evaluate(state.occupied_cells, Ids.WALL, Vector2i(5, 4))
	_ok(not again.ok, "second wall rejected")
	state.free_serial(serial)
	_ok(state.serial_at(Vector2i(5, 4)) < 0, "dismantle frees cell")


func _death_and_respawn() -> void:
	print("death and respawn")
	var survive := ModeCatalog.by_id(Ids.MODE_SURVIVE)
	var state := GameState.new()
	state.begin(survive)
	state.resources[Ids.SCRAP] = 20
	state.player_health = 0.0
	state.player_alive = false
	state.resources = Economy.tax(state.resources, survive.death_scrap_tax_ratio)
	_ok(not state.player_alive, "player down")
	_ok(int(state.resources[Ids.SCRAP]) == 17, "scrap tax on death")
	if state.core_health > 0.0:
		state.player_alive = true
		state.player_health = state.player_max_health
	_ok(state.player_alive and state.player_health == state.player_max_health, "respawn if core lives")
	state.core_health = 0.0
	_ok(WinEvaluator.evaluate(state, survive) == WinEvaluator.Outcome.DEFEAT, "core loss ends run")
	var escape := ModeCatalog.by_id(Ids.MODE_ESCAPE)
	state = GameState.new()
	state.begin(escape)
	state.resources = {Ids.SCRAP: 200, Ids.CRYSTAL: 200}
	var ship_place := PlacementRules.evaluate(state.occupied_cells, Ids.ESCAPE_SHIP, Vector2i(6, 6))
	_ok(ship_place.ok, "ship cell valid")
	state.escape_ship_built = true
	_ok(WinEvaluator.evaluate(state, escape) == WinEvaluator.Outcome.VICTORY, "escape wins")
