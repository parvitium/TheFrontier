class_name GameState
extends RefCounted

enum Phase { REST, WAVE, VICTORY, DEFEAT }

var mode_id: String = ""
var phase: Phase = Phase.REST
var elapsed_time: float = 0.0
var rest_remaining: float = 0.0
var wave_index: int = 0
var waves_completed: int = 0
var mobs_alive: int = 0
var mobs_spawned_this_wave: int = 0
var mobs_to_spawn_this_wave: int = 0
var score: int = 0
var kills: int = 0
var core_health: float = 400.0
var core_max_health: float = 400.0
var player_health: float = 100.0
var player_max_health: float = 100.0
var player_alive: bool = true
var respawn_in: float = 0.0
var resources: Dictionary = Economy.empty_wallet()
var occupied_cells: Dictionary = {}
var building_instances: Dictionary = {}
var next_building_serial: int = 1
var relics_collected: int = 0
var escape_ship_built: bool = false
var buildings_destroyed: int = 0
var building_hp: Dictionary = {}
var building_max_hp: Dictionary = {}
var turret_cooldown: Dictionary = {}
var weapons: Array = []
var selected_weapon: int = 0
var fire_cooldown: float = 0.0
var reload_remaining: float = 0.0


func begin(mode: GameModeDef) -> void:
	mode_id = mode.id
	phase = Phase.REST
	elapsed_time = 0.0
	rest_remaining = mode.first_rest_seconds
	wave_index = 0
	waves_completed = 0
	mobs_alive = 0
	mobs_spawned_this_wave = 0
	mobs_to_spawn_this_wave = 0
	score = 0
	kills = 0
	core_max_health = mode.core_max_health
	core_health = mode.core_max_health
	player_max_health = mode.player_max_health
	player_health = mode.player_max_health
	player_alive = true
	respawn_in = 0.0
	resources = {
		Ids.SCRAP: mode.starting_scrap,
		Ids.CRYSTAL: mode.starting_crystal,
	}
	occupied_cells.clear()
	building_instances.clear()
	next_building_serial = 1
	relics_collected = 0
	escape_ship_built = false
	buildings_destroyed = 0
	building_hp.clear()
	building_max_hp.clear()
	turret_cooldown.clear()
	weapons.clear()
	for def in WeaponCatalog.all():
		weapons.append({
			"id": def.id,
			"mag": def.magazine_size,
			"reserve": def.reserve,
		})
	selected_weapon = 0
	fire_cooldown = 0.0
	reload_remaining = 0.0


func is_running() -> bool:
	return phase == Phase.REST or phase == Phase.WAVE


func occupy(cells: Array[Vector2i], building_id: String) -> int:
	var serial := next_building_serial
	next_building_serial += 1
	building_instances[serial] = {id = building_id, cells = cells}
	for cell in cells:
		occupied_cells[cell] = serial
	return serial


func serial_at(cell: Vector2i) -> int:
	return int(occupied_cells.get(cell, -1))


func building_id_of(serial: int) -> String:
	if not building_instances.has(serial):
		return ""
	return str(building_instances[serial].id)


func free_serial(serial: int) -> String:
	if not building_instances.has(serial):
		return ""
	var info: Dictionary = building_instances[serial]
	for cell in info.cells:
		occupied_cells.erase(cell)
	building_instances.erase(serial)
	return str(info.id)
