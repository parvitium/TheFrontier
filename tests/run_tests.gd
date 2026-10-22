extends Node

var _failed: int = 0
var _passed: int = 0


func _ready() -> void:
	print("TheFrontier headless tests")
	_economy()
	_building_costs()
	_placement()
	_wave_scaling()
	_win_conditions()
	_breach()
	_session_survive()
	_session_gather()
	_session_escape()
	_session_endless()
	_session_economy_and_buildings()
	_session_combat_and_ammo()
	_session_death_and_respawn()
	_session_pause()
	_resource_restock()
	print("Passed: %d  Failed: %d" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _ok(cond: bool, name: String) -> void:
	if cond:
		_passed += 1
		print("  PASS  ", name)
	else:
		_failed += 1
		print("  FAIL  ", name)


func _boot(mode_id: String) -> void:
	Session.set_paused(false)
	Session.start_run(mode_id)


func _clear_wave_via_session() -> void:
	if Session.state.phase == GameState.Phase.REST:
		Session.tick(Session.state.rest_remaining + 0.05)
	var n: int = Session.state.mobs_to_spawn_this_wave
	for _i in n:
		Session.cmd_mob_spawned()
	for _i in n:
		Session.cmd_mob_killed(Ids.RUSHER)


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
	_ok((Hitscan.HOSTILE_MASK & 8) != 0, "player shots blocked by building layer")


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
	var fill := BuildingBase.footprint_collider_size(Vector2i.ONE)
	_ok(is_equal_approx(fill.x, PlacementRules.CELL_SIZE) and is_equal_approx(fill.z, PlacementRules.CELL_SIZE), "wall collider fills 2m cell")


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


func _breach() -> void:
	print("breach")
	var occupied := {}
	var serial := 1
	for x in range(-2, 3):
		for y in range(-2, 3):
			if maxi(absi(x), absi(y)) == 2:
				occupied[Vector2i(x, y)] = serial
				serial += 1
	_ok(occupied.size() == 16, "closed ring is 16 cells")
	_ok(not BreachRules.core_reachable(occupied, Vector2i(10, 0)), "ring blocks core from outside")
	var blockers := BreachRules.blocking_serials(occupied, Vector2i(10, 0))
	_ok(blockers.size() > 0, "unreachable core yields breach serials")
	occupied.erase(Vector2i(2, 0))
	_ok(BreachRules.core_reachable(occupied, Vector2i(10, 0)), "gap opens a path to the core")
	_ok(BreachRules.blocking_serials(occupied, Vector2i(10, 0)).is_empty(), "reachable core has no breach list")
	_boot(Ids.MODE_SURVIVE)
	Session.cmd_gather(Ids.SCRAP, 200)
	var placed := 0
	for x2 in range(-2, 3):
		for y2 in range(-2, 3):
			if maxi(absi(x2), absi(y2)) == 2:
				var result: Dictionary = Session.cmd_try_place(Ids.WALL, Vector2i(x2, y2))
				if result.ok:
					placed += 1
	_ok(placed == 16, "session allows a closed wall ring")
	_ok(not BreachRules.core_reachable(Session.state.occupied_cells, Vector2i(12, 0)), "session ring encloses the core")
	_ok(BreachRules.blocking_serials(Session.state.occupied_cells, Vector2i(12, 0)).size() > 0, "session ring has attackable walls")


func _session_survive() -> void:
	print("session survive")
	_boot(Ids.MODE_SURVIVE)
	_ok(Session.state.phase == GameState.Phase.REST, "survive starts resting")
	_ok(int(Session.state.resources[Ids.SCRAP]) == 45, "survive starting scrap")
	Session.cmd_damage_core(9999.0)
	_ok(Session.state.phase == GameState.Phase.DEFEAT, "survive core death is defeat")
	_ok(Session.last_outcome == WinEvaluator.Outcome.DEFEAT, "survive last outcome defeat")
	_ok(not Session.cmd_try_place(Ids.WALL, Vector2i(5, 5)).ok, "survive refuses place after defeat")
	_boot(Ids.MODE_SURVIVE)
	for _wave in 3:
		_clear_wave_via_session()
	_ok(Session.state.waves_completed == 3, "survive cleared 3 waves via Session")
	_ok(Session.state.phase == GameState.Phase.VICTORY, "survive wins after 3 Session wave-clears")
	_ok(Session.last_outcome == WinEvaluator.Outcome.VICTORY, "survive last outcome victory")


func _session_gather() -> void:
	print("session gather")
	_boot(Ids.MODE_GATHER)
	_ok(int(Session.state.resources[Ids.SCRAP]) == 40, "gather starting scrap")
	Session.cmd_damage_core(9999.0)
	_ok(Session.state.phase == GameState.Phase.DEFEAT, "gather core death is defeat")
	_boot(Ids.MODE_GATHER)
	for _i in 4:
		Session.cmd_collect_relic()
	_ok(Session.state.relics_collected == 4, "gather collected 4 relics via Session")
	_ok(Session.state.phase == GameState.Phase.VICTORY, "gather wins at 4 relics")
	Session.cmd_collect_relic()
	_ok(Session.state.relics_collected == 4, "gather ignores extra relic after win")


func _session_escape() -> void:
	print("session escape")
	_boot(Ids.MODE_ESCAPE)
	_ok(int(Session.state.resources[Ids.SCRAP]) == 35, "escape starting scrap")
	Session.cmd_damage_core(9999.0)
	_ok(Session.state.phase == GameState.Phase.DEFEAT, "escape core death is defeat")
	_boot(Ids.MODE_ESCAPE)
	Session.cmd_gather(Ids.SCRAP, 50)
	Session.cmd_gather(Ids.CRYSTAL, 30)
	var ship: Dictionary = Session.cmd_try_place(Ids.ESCAPE_SHIP, Vector2i(6, 6))
	_ok(ship.ok, "escape ship place via Session")
	_ok(Session.state.escape_ship_built, "escape flag set")
	_ok(Session.state.phase == GameState.Phase.VICTORY, "escape wins on ship place")
	_ok(not Session.cmd_try_place(Ids.WALL, Vector2i(8, 8)).ok, "escape refuses place after victory")


func _session_endless() -> void:
	print("session endless")
	_boot(Ids.MODE_ENDLESS)
	_ok(int(Session.state.resources[Ids.SCRAP]) == 50, "endless starting scrap")
	_ok(Session.mode.relics_on_map > 0, "endless lists relics on the map")
	_clear_wave_via_session()
	_ok(Session.state.waves_completed == 1, "endless cleared a wave via Session")
	_ok(Session.state.phase == GameState.Phase.REST, "endless returns to rest")
	var score_after_wave: int = Session.state.score
	Session.cmd_collect_relic()
	_ok(Session.state.relics_collected == 1, "endless relic pickup")
	_ok(Session.state.score == score_after_wave + 50, "endless relic adds score")
	_ok(Session.state.phase != GameState.Phase.VICTORY, "endless never wins")
	Session.cmd_damage_core(9999.0)
	_ok(Session.state.phase == GameState.Phase.DEFEAT, "endless loses on core death")


func _session_economy_and_buildings() -> void:
	print("session economy")
	_boot(Ids.MODE_SURVIVE)
	_ok(Session.cmd_gather(Ids.SCRAP, 10), "gather scrap via Session")
	_ok(int(Session.state.resources[Ids.SCRAP]) == 55, "wallet after gather")
	var wall: Dictionary = Session.cmd_try_place(Ids.WALL, Vector2i(5, 4))
	_ok(wall.ok, "place wall via Session")
	_ok(Session.state.serial_at(Vector2i(5, 4)) == int(wall.serial), "serial stored")
	_ok(is_equal_approx(float(Session.state.building_hp[wall.serial]), 80.0), "wall hp registered")
	_ok(not Session.cmd_try_place(Ids.WALL, Vector2i(5, 4)).ok, "second wall rejected")
	var dismantle: Dictionary = Session.cmd_dismantle_at(Vector2i(5, 4))
	_ok(dismantle.ok, "dismantle via Session")
	_ok(int(dismantle.refund[Ids.SCRAP]) == 4, "wall refund 50 percent")
	_ok(Session.state.serial_at(Vector2i(5, 4)) < 0, "dismantle frees cell")
	_ok(not Session.cmd_dismantle_at(Vector2i(5, 4)).ok, "no double refund")
	Session.cmd_gather(Ids.SCRAP, 20)
	Session.cmd_gather(Ids.CRYSTAL, 10)
	var turret: Dictionary = Session.cmd_try_place(Ids.TURRET, Vector2i(6, 4))
	_ok(turret.ok, "place turret via Session")
	var refund2: Dictionary = Session.cmd_dismantle_at(Vector2i(6, 4))
	_ok(refund2.ok and int(refund2.refund[Ids.SCRAP]) == 12 and int(refund2.refund[Ids.CRYSTAL]) == 5, "turret refund 12/5")


func _session_combat_and_ammo() -> void:
	print("session combat")
	_boot(Ids.MODE_SURVIVE)
	Session.cmd_gather(Ids.SCRAP, 40)
	var wall: Dictionary = Session.cmd_try_place(Ids.WALL, Vector2i(5, 5))
	_ok(wall.ok, "combat wall placed")
	var hp := float(Session.state.building_hp[wall.serial])
	var friendly: Dictionary = Session.cmd_apply_damage("player", "building", wall.serial, 25.0)
	_ok(not friendly.ok, "player shots do not damage own buildings")
	_ok(is_equal_approx(float(Session.state.building_hp[wall.serial]), hp), "friendly fire left hp")
	var mob_hit: Dictionary = Session.cmd_apply_damage("mob", "building", wall.serial, 20.0)
	_ok(mob_hit.ok, "mob damages buildings")
	_ok(is_equal_approx(float(Session.state.building_hp[wall.serial]), hp - 20.0), "building hp dropped")
	Session.cmd_heal_building(int(wall.serial), 5.0)
	_ok(is_equal_approx(float(Session.state.building_hp[wall.serial]), hp - 15.0), "beacon-style heal via Session")
	var killed: Dictionary = Session.cmd_damage_building(int(wall.serial), 999.0)
	_ok(killed.died, "building death via Session")
	_ok(Session.state.serial_at(Vector2i(5, 5)) < 0, "destroyed building frees grid")
	var rifle := WeaponCatalog.by_id(Ids.RIFLE)
	var shot: Dictionary = Session.cmd_try_fire()
	_ok(shot.ok and float(shot.damage) == rifle.damage, "fire consumes Session ammo")
	_ok(int(Session.state.weapons[0].mag) == rifle.magazine_size - 1, "mag decremented")
	_ok(not Session.cmd_try_fire().ok, "fire cooldown blocks")
	Session.tick(rifle.fire_interval + 0.01)
	_ok(Session.cmd_try_fire().ok, "fire after cooldown")
	Session.cmd_select_weapon(1)
	_ok(Session.state.selected_weapon == 1, "switch weapon")
	_ok(Session.cmd_start_reload() == false or Session.state.reload_remaining >= 0.0, "reload API reachable")
	Session.cmd_select_weapon(0)
	while int(Session.state.weapons[0].mag) > 0:
		Session.tick(1.0)
		if not Session.cmd_try_fire().ok:
			break
	Session.tick(1.0)
	Session.cmd_try_fire()
	_ok(Session.state.reload_remaining > 0.0, "empty mag starts reload")
	Session.tick(rifle.reload_time + 0.05)
	_ok(int(Session.state.weapons[0].mag) == rifle.magazine_size, "reload finishes on tick")


func _session_death_and_respawn() -> void:
	print("session death")
	_boot(Ids.MODE_SURVIVE)
	var scrap_before := int(Session.state.resources[Ids.SCRAP])
	Session.cmd_damage_player(999.0)
	_ok(not Session.state.player_alive, "player down via Session")
	_ok(int(Session.state.resources[Ids.SCRAP]) == int(floor(float(scrap_before) * 0.85)), "scrap tax on death")
	_ok(int(Session.state.resources[Ids.CRYSTAL]) == 16, "crystal untouched")
	Session.tick(4.9)
	_ok(not Session.state.player_alive, "still down before 5s")
	Session.tick(0.2)
	_ok(Session.state.player_alive and is_equal_approx(Session.state.player_health, Session.state.player_max_health), "respawn if core lives")
	_boot(Ids.MODE_SURVIVE)
	Session.cmd_damage_player(999.0)
	Session.cmd_damage_core(9999.0)
	Session.tick(10.0)
	_ok(not Session.state.player_alive, "no respawn after core death")
	_ok(Session.state.phase == GameState.Phase.DEFEAT, "core loss ends run")


func _session_pause() -> void:
	print("session pause")
	_boot(Ids.MODE_SURVIVE)
	var rest: float = float(Session.state.rest_remaining)
	Session.set_paused(true)
	Session.tick(5.0)
	_ok(is_equal_approx(Session.state.rest_remaining, rest), "pause freezes Session.tick")
	_ok(is_equal_approx(Session.state.elapsed_time, 0.0), "pause freezes elapsed")
	Session.set_paused(false)
	Session.tick(5.0)
	_ok(Session.state.rest_remaining < rest, "unpause resumes rest clock")


func _resource_restock() -> void:
	print("resource restock")
	var node := ResourceNode.new()
	node.respawn_amount = 12
	node.remaining = 5
	node.restock()
	_ok(node.remaining == 12, "partial nodes restock to full")
	node.remaining = 0
	node.restock()
	_ok(node.remaining == 12, "empty nodes still restock")
	node.free()
