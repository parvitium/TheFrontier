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
	_settings_and_visuals()
	_terrain_and_seating()
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
	_ok(is_equal_approx(fill.y, 1.8), "nav-blocking collider is 1.8m tall")
	_ok(BuildingBase.uses_blocking_collider(BuildingCatalog.by_id(Ids.WALL)), "wall uses blocking collider")
	_ok(BuildingBase.uses_blocking_collider(BuildingCatalog.by_id(Ids.TURRET)), "turret uses blocking collider")
	_ok(not BuildingBase.uses_blocking_collider(BuildingCatalog.by_id(Ids.TRAP)), "trap uses no blocking collider")
	_boot(Ids.MODE_SURVIVE)
	var wall_actor := WallBuilding.new()
	add_child(wall_actor)
	wall_actor.setup(BuildingCatalog.by_id(Ids.WALL), Vector2i(8, 8), 900)
	_ok(wall_actor.collision_layer == 8, "wall lives on building physics layer")
	_ok(_direct_box_height(wall_actor) > 1.5, "wall blocking box is chest-high")
	var trap_actor := TrapBuilding.new()
	add_child(trap_actor)
	trap_actor.setup(BuildingCatalog.by_id(Ids.TRAP), Vector2i(9, 8), 901)
	_ok(trap_actor.collision_layer == 0, "trap has no blocking physics layer")
	_ok(_direct_box_height(trap_actor) == 0.0, "trap has no blocking CollisionShape3D")
	wall_actor.free()
	trap_actor.free()


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
	var pad := PlacementRules.sample_footprint(Ids.WALL, Vector2i(4, 4))
	_ok(float(pad.relief) < PlacementRules.MAX_RELIEF, "inner pad footprint is even enough")
	_ok(float(pad.slope_deg) < PlacementRules.MAX_SLOPE_DEG, "inner pad footprint is not too steep")
	var seated := PlacementRules.seat_origin(Ids.WALL, Vector2i(4, 4))
	_ok(is_equal_approx(seated.x, 8.0) and is_equal_approx(seated.z, 8.0), "seat keeps cell xz")
	_ok(is_equal_approx(seated.y, float(pad.avg_y) - PlacementRules.FOUNDATION_SINK), "seat uses average height minus sink")
	_ok(PlacementRules.evaluate({}, Ids.ESCAPE_SHIP, Vector2i(5, 5)).ok, "2x2 ship still places on a mild wash")
	_ok(PlacementRules.evaluate({}, Ids.TURRET, Vector2i(7, 5)).ok, "turret still places on a mild bank")
	var dune_cell := PlacementRules.world_to_cell(Vector3(10.0, 0.0, -21.0))
	var dune := PlacementRules.sample_footprint(Ids.WALL, dune_cell)
	_ok(float(dune.max_y) > Landscape.height_at(0.0, 0.0) + 0.2, "dune sample is above the core pad")
	_ok(absf(float(dune.min_y) - Landscape.height_at(float(dune_cell.x) * 2.0, float(dune_cell.y) * 2.0)) < 0.6, "dune sample tracks height_at")
	var wash := PlacementRules.seat_origin(Ids.WALL, PlacementRules.world_to_cell(Vector3(-12.2, 0.0, 0.0)))
	_ok(wash.y < Landscape.height_at(0.0, 0.0) - 0.15, "wash seating sits below the core pad")
	_ok(not _pipe_row_is_raw_markdown(), "credits tables are formatted, not raw pipes")


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
	_ok(not BreachRules.core_reachable(Session.state.occupied_cells, Vector2i(12, 0), Session.state.building_instances), "session ring encloses the core")
	_ok(BreachRules.blocking_serials(Session.state.occupied_cells, Vector2i(12, 0), Session.state.building_instances).size() > 0, "session ring has attackable walls")
	_boot(Ids.MODE_SURVIVE)
	Session.cmd_gather(Ids.SCRAP, 200)
	Session.cmd_gather(Ids.CRYSTAL, 20)
	var trap_ring := 0
	for x3 in range(-2, 3):
		for y3 in range(-2, 3):
			if maxi(absi(x3), absi(y3)) != 2:
				continue
			var id := Ids.TRAP if x3 == 2 and y3 == 0 else Ids.WALL
			if Session.cmd_try_place(id, Vector2i(x3, y3)).ok:
				trap_ring += 1
	_ok(trap_ring == 16, "session places a 15-wall ring with a trap gap")
	_ok(BreachRules.core_reachable(Session.state.occupied_cells, Vector2i(12, 0), Session.state.building_instances), "trap gap is passable to the flood")
	_ok(BreachRules.blocking_serials(Session.state.occupied_cells, Vector2i(12, 0), Session.state.building_instances).is_empty(), "trap gap has no breach list")
	_ok(not BreachRules.cell_blocks(Session.state.occupied_cells, Vector2i(2, 0), Session.state.building_instances), "trap cell is not solid")


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
	var mob := MobActor.new()
	add_child(mob)
	mob.configure(MobCatalog.by_id(Ids.RUSHER))
	var health := mob.get_node("Health") as Health
	var before := health.current
	_ok(Session.cmd_damage_mob(mob, 10.0), "Session damages a live MobActor")
	_ok(is_equal_approx(health.current, before - 10.0), "MobActor HP dropped through Session")
	mob.free()


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
	Session.cmd_gather(Ids.SCRAP, 40)
	Session.cmd_gather(Ids.CRYSTAL, 20)
	var turret: Dictionary = Session.cmd_try_place(Ids.TURRET, Vector2i(7, 5))
	var trap: Dictionary = Session.cmd_try_place(Ids.TRAP, Vector2i(7, 6))
	_ok(turret.ok and trap.ok, "pause fixtures placed")
	var rest: float = float(Session.state.rest_remaining)
	var mag: int = int(Session.state.weapons[0].mag)
	Session.set_paused(true)
	Session.tick(5.0)
	_ok(is_equal_approx(Session.state.rest_remaining, rest), "pause freezes Session.tick")
	_ok(is_equal_approx(Session.state.elapsed_time, 0.0), "pause freezes elapsed")
	var paused_fire: Dictionary = Session.cmd_try_fire()
	_ok(not paused_fire.ok, "pause rejects fire")
	_ok(int(Session.state.weapons[0].mag) == mag, "pause fire does not consume ammo")
	_ok(not Session.cmd_try_turret_fire(int(turret.serial), self, 15.0), "pause rejects turret")
	_ok(is_equal_approx(float(Session.state.turret_cooldown.get(int(turret.serial), 0.0)), 0.0), "pause turret does not write cooldown")
	_ok(not Session.cmd_trap_pulse(int(trap.serial), self, 0.16), "pause rejects trap")
	Session.set_paused(false)
	Session.tick(5.0)
	_ok(Session.state.rest_remaining < rest, "unpause resumes rest clock")
	_ok(Session.cmd_try_fire().ok, "unpause allows fire")


func _direct_box_height(node: Node) -> float:
	for child in node.get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape is BoxShape3D:
			return ((child as CollisionShape3D).shape as BoxShape3D).size.y
	return 0.0


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


func _settings_and_visuals() -> void:
	print("settings and visuals")
	var prev_q: int = GameSettings.quality
	var prev_fov: float = GameSettings.fov
	var prev_sens: float = GameSettings.mouse_sensitivity
	GameSettings.set_quality(GameSettings.Quality.LOW)
	_ok(GameSettings.quality == GameSettings.Quality.LOW, "quality low")
	GameSettings.set_quality(GameSettings.Quality.ULTRA)
	_ok(GameSettings.quality == GameSettings.Quality.ULTRA, "quality ultra")
	GameSettings.set_fov(90.0)
	_ok(is_equal_approx(GameSettings.fov, 90.0), "fov set")
	GameSettings.set_mouse_sensitivity(1.4)
	_ok(is_equal_approx(GameSettings.mouse_sensitivity, 1.4), "sensitivity set")
	var env := WorldLook.make_environment(false)
	_ok(env.tonemap_mode == Environment.TONE_MAPPER_AGX, "AgX tonemapper")
	_ok(env.glow_enabled, "glow enabled on env")
	GameSettings.apply_environment(env)
	_ok(VisualKit.has_slot("core_engine"), "core kit present")
	_ok(VisualKit.has_slot("building_wall"), "wall kit present")
	_ok(VisualKit.has_slot("mob_rusher"), "rusher kit present")
	_ok(VisualKit.has_slot("pulse_rifle"), "rifle kit present")
	var metal := PbrLibrary.metal()
	_ok(metal != null and metal.metallic > 0.4, "pbr metal material")
	_ok(PbrLibrary.TREAD_DIR.find("metal_plate") != -1, "tread uses diamond plate")
	_ok(PbrLibrary.PAINT_DIR.find("painted") != -1, "painted steel is a separate set")
	_ok(PbrLibrary.CORRUG_DIR.find("corrugated") != -1, "corrugated panels are a separate set")
	_ok(PbrLibrary.by_kit_name("Tread") != PbrLibrary.by_kit_name("Oxidized"), "oxidized steel is not diamond plate")
	_ok(PbrLibrary.by_kit_name("Corrugated") != PbrLibrary.by_kit_name("Tread"), "corrugated panels are not diamond plate")
	_ok(PbrLibrary.by_kit_name("PaintedMetal") != PbrLibrary.by_kit_name("Tread"), "painted sheet is not diamond plate")
	var poly := PbrLibrary.polymer()
	_ok(poly != null and poly.metallic < 0.2, "polymer is non-metal")
	var rifle := KitFactory.build("pulse_rifle")
	_ok(rifle != null and VisualKit.find_node(rifle, "Muzzle") != null, "rifle kit has muzzle")
	_ok(VisualKit.find_node(rifle, "Stock") != null, "rifle kit has stock")
	_ok(VisualKit.find_node(rifle, "Receiver") != null, "rifle kit has receiver")
	_ok(VisualKit.find_node(rifle, "OpticTube") != null, "rifle has optic tube")
	_ok(VisualKit.find_node(rifle, "OpticLens") != null, "rifle has glass lens")
	_ok(VisualKit.find_node(rifle, "Barrel") != null, "rifle has tapered barrel")
	_ok(VisualKit.find_node(rifle, "StockTube") != null, "rifle has rounded stock tube")
	_ok(VisualKit.find_node(rifle, "ReceiverRound") != null, "rifle has rounded receiver")
	_ok(VisualKit.find_node(rifle, "Handguard") != null, "rifle has a handguard")
	_ok(VisualKit.find_node(rifle, "Mag") != null, "rifle has a magazine")
	_ok(VisualKit.find_node(rifle, "OpticKnob") != null, "rifle optic has adjustment knobs")
	rifle.free()
	var wall := KitFactory.build("building_wall")
	_ok(wall != null and wall.find_child("PanelA0", true, false) != null, "wall has panel seams")
	_ok(wall.find_child("Roof", true, false) != null, "wall has angled roof")
	_ok(wall.find_child("Sandbag0", true, false) != null, "wall has sandbags")
	_ok(wall.find_child("Antenna", true, false) != null, "wall has antenna")
	_ok(wall.find_child("Brace0", true, false) != null, "wall has bracing")
	_ok(wall.find_child("HullChamferX", true, false) != null, "wall has hull chamfer")
	_ok(wall.find_child("CornerPost0", true, false) != null, "wall has corner posts")
	_ok(wall.find_child("Rivet0_0", true, false) != null, "wall has panel rivets")
	_ok(wall.find_child("HullBevel0", true, false) != null, "wall has vertical bevels")
	_ok(wall.find_child("Buttress0", true, false) != null, "wall has a buttress")
	_ok(wall.find_child("Weld0", true, false) != null, "wall has welded seams")
	_ok(wall.find_child("Gusset0", true, false) != null, "wall has corner gussets")
	_ok(wall.find_child("Lod0_0", true, false) != null, "wall kit is batched into lod meshes")
	wall.free()
	var turret := KitFactory.build("building_turret")
	_ok(turret != null and turret.find_child("Yoke", true, false) != null, "turret has a yoke")
	_ok(turret.find_child("Shroud", true, false) != null, "turret has a barrel shroud")
	_ok(turret.find_child("Head", true, false) != null, "turret head is a named node")
	_ok(VisualKit.find_node(turret, "Muzzle") != null, "turret has a muzzle")
	turret.free()
	var core := KitFactory.build("core_engine")
	_ok(core != null and core.find_child("Foundation", true, false) != null, "core has foundation")
	core.free()
	_ok(is_equal_approx(Landscape.height_at(0, 0), Landscape.height_at(0, 0)), "landscape height deterministic")
	_ok(absf(Landscape.height_at(0, 0)) < 0.5, "basin near origin is playable-flat")
	_ok(Landscape.height_at(180, 0) > 8.0, "distant terrain rises into mesas")
	_ok(Landscape.height_at(-12.2, 0.0) < Landscape.height_at(-18.0, 0.0) - 0.35, "dry riverbed sits below its bank")
	_ok(Landscape.height_at(10.0, -21.0) > Landscape.height_at(0.0, 0.0) + 0.2, "dune ridge rises off the core pad")
	var mesa_cap := Landscape.height_at(78.0, -96.0)
	var mesa_near := Landscape.height_at(83.0, -96.0)
	var mesa_talus := Landscape.height_at(78.0 + 20.0, -96.0)
	_ok(mesa_cap > 8.0, "mesa center is a carved landform")
	_ok(absf(mesa_cap - mesa_near) > 0.12, "mesa top is eroded, not a table")
	_ok(mesa_talus < mesa_cap - 1.5, "mesa talus sits below the cap")
	_ok(Landscape.PLAY_QUADS > Landscape.COL_VERTS - 1, "playfield visual is denser than 1 m collision")
	_ok(Landscape.NEAR_SIZE / float(Landscape.NEAR_QUADS) < Landscape.MAP_COLLISION / float(Landscape.PLAY_QUADS), "near sand is finer than the playfield grid")
	_ok(PbrLibrary.BOULDER_DIR.find("rock_08") != -1, "boulders use CC0 rock_08")
	_ok(ResourceLoader.exists(PbrLibrary.BOULDER_SHADER), "boulder shader is present")
	var boulder := KitFactory.boulder_mesh(11, Vector3(1.2, 0.7, 1.1), 10, 7)
	_ok(boulder != null and boulder.get_surface_count() > 0, "boulder mesh generates")
	_ok(ResourceLoader.exists(WorldLook.HDRI_PATH), "desert puresky HDRI present")
	var hud := Hud.new()
	add_child(hud)
	var banner := hud.find_child("Banner", true, false) as Label
	var plate := hud.find_child("BannerPlate", true, false)
	_ok(banner != null and banner.get_theme_constant("outline_size") >= 6, "banner text is outlined")
	_ok(plate != null and plate.visible, "banner sits on a dark plate")
	var film := plate.get_theme_stylebox("panel") as StyleBoxFlat
	_ok(film != null and film.bg_color.a <= 0.4, "banner plate is translucent")
	hud.free()
	GameSettings.set_quality(prev_q)
	GameSettings.set_fov(prev_fov)
	GameSettings.set_mouse_sensitivity(prev_sens)


func _terrain_and_seating() -> void:
	print("terrain collision and seating")
	var shape := Landscape.make_heightmap_shape()
	_ok(shape is HeightMapShape3D, "playfield collider is a heightmap")
	_ok(shape.map_width == Landscape.COL_VERTS and shape.map_depth == Landscape.COL_VERTS, "heightmap covers playfield verts")
	_ok(shape.map_data.size() == Landscape.COL_VERTS * Landscape.COL_VERTS, "heightmap data matches verts")
	var mid := Landscape.COL_VERTS / 2
	var xz := Landscape.col_world_xz(mid, mid)
	_ok(absf(shape.map_data[mid * Landscape.COL_VERTS + mid] - Landscape.height_at(xz.x, xz.y)) < 0.001, "heightmap origin matches height_at")
	var dune_i := 0
	var dune_k := 0
	var best := 0.0
	for iz in Landscape.COL_VERTS:
		for ix in Landscape.COL_VERTS:
			var p := Landscape.col_world_xz(ix, iz)
			if absf(p.x - 10.0) + absf(p.y + 21.0) < absf(Landscape.col_world_xz(dune_i, dune_k).x - 10.0) + absf(Landscape.col_world_xz(dune_i, dune_k).y + 21.0):
				dune_i = ix
				dune_k = iz
			best = maxf(best, absf(shape.map_data[iz * Landscape.COL_VERTS + ix]))
	var dune_xz := Landscape.col_world_xz(dune_i, dune_k)
	_ok(absf(shape.map_data[dune_k * Landscape.COL_VERTS + dune_i] - Landscape.height_at(dune_xz.x, dune_xz.y)) < 0.001, "heightmap dune sample matches height_at")
	_ok(best > 0.5, "heightmap stores real relief, not a flat y=0 plane")
	var seated := Landscape.seat(Vector3(10, 99, -21))
	_ok(is_equal_approx(seated.y, Landscape.height_at(10, -21)), "seat y follows height_at")
	_ok(is_equal_approx(seated.x, 10.0) and is_equal_approx(seated.z, -21.0), "seat keeps xz")
	_ok(Landscape.slope_deg(0.0, 0.0) < 8.0, "core pad slope is walkable")
	var root := Node3D.new()
	add_child(root)
	Landscape.build(root, true)
	var ground := root.find_child("Ground", true, false) as StaticBody3D
	_ok(ground != null, "landscape builds a Ground body")
	var col: CollisionShape3D = null
	if ground:
		col = ground.get_node_or_null("HeightMap") as CollisionShape3D
	_ok(col != null and col.shape is HeightMapShape3D, "Ground uses HeightMapShape3D, not a y=0 box")
	var playfield := root.find_child("Playfield", true, false)
	_ok(playfield != null, "playfield visual mesh matches collision grid")
	_ok(root.find_child("NearSand", true, false) != null, "near-player sand mesh exists")
	_ok(root.find_child("CoverBoulders", true, false) != null, "cover rocks are instanced")
	_ok(root.find_child("HorizonImpostors", true, false) != null, "horizon uses impostors")
	var talus_n := root.find_child("MesaTalus0", true, false) as Node3D
	_ok(talus_n != null, "mesa talus debris exists")
	if talus_n:
		var hy := Landscape.height_at(talus_n.global_position.x, talus_n.global_position.z)
		_ok(talus_n.global_position.y < hy + 0.25 and talus_n.global_position.y > hy - 2.4, "mesa talus is seated on height_at")
	root.free()
	_ok(CreditsPanel.markdown_to_bbcode("# Title\n| A | B |\n| --- | --- |\n| one | two |").find("[b]A[/b]") != -1, "markdown tables become formatted credits")
	_ok(CreditsPanel.markdown_to_bbcode("# Title").find("|") == -1, "formatted credits drop raw table pipes")


func _pipe_row_is_raw_markdown() -> bool:
	var text := CreditsPanel.markdown_to_bbcode(_assets_md_head())
	return text.find("| ---") != -1 or text.begins_with("# ")


func _assets_md_head() -> String:
	if FileAccess.file_exists("res://ASSETS.md"):
		var f := FileAccess.open("res://ASSETS.md", FileAccess.READ)
		if f:
			return f.get_as_text()
	return "# Assets\n| A | B |\n| --- | --- |\n| x | y |"
