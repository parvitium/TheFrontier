extends Node

signal run_started(mode_id: String)
signal phase_changed(phase: int)
signal wave_started(index: int)
signal wave_cleared(index: int)
signal resources_changed(wallet: Dictionary)
signal core_health_changed(current: float, maximum: float)
signal player_health_changed(current: float, maximum: float)
signal player_died
signal player_respawned
signal building_placed(building_id: String, origin: Vector2i)
signal building_destroyed(building_id: String, serial: int)
signal building_health_changed(serial: int, current: float, maximum: float)
signal mob_killed(mob_id: String)
signal relic_collected(count: int, needed: int)
signal run_ended(outcome: int, stats: Dictionary)
signal banner(text: String)
signal nav_dirty
signal restock_ammo
signal ammo_changed
