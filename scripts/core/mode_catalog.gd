class_name ModeCatalog
extends RefCounted


static func all() -> Array[GameModeDef]:
	var loaded := _load_dir("res://data/modes")
	if loaded.size() >= 4:
		return loaded
	return [_survive(), _gather(), _escape(), _endless()]


static func by_id(id: String) -> GameModeDef:
	for mode in all():
		if mode.id == id:
			return mode
	return _survive()


static func _load_dir(path: String) -> Array[GameModeDef]:
	var out: Array[GameModeDef] = []
	var dir := DirAccess.open(path)
	if dir == null:
		return out
	var names: PackedStringArray = dir.get_files()
	names.sort()
	for file_name in names:
		if file_name.ends_with(".tres"):
			var res := load(path.path_join(file_name))
			if res is GameModeDef:
				out.append(res)
	return out


static func _survive() -> GameModeDef:
	var m := GameModeDef.new()
	m.id = Ids.MODE_SURVIVE
	m.display_name = "Survive"
	m.description = "Hold the core through 3 waves. The planet does not care if you are ready."
	m.kind = GameModeDef.Kind.SURVIVE
	m.survive_waves = 3
	m.starting_scrap = 45
	m.starting_crystal = 16
	m.rest_seconds = 22.0
	m.first_rest_seconds = 18.0
	return m


static func _gather() -> GameModeDef:
	var m := GameModeDef.new()
	m.id = Ids.MODE_GATHER
	m.display_name = "Gather"
	m.description = "Recover 4 signal relics scattered around the basin before the core fails."
	m.kind = GameModeDef.Kind.GATHER
	m.gather_count = 4
	m.relics_on_map = 6
	m.starting_scrap = 40
	m.starting_crystal = 12
	m.rest_seconds = 20.0
	m.first_rest_seconds = 16.0
	return m


static func _escape() -> GameModeDef:
	var m := GameModeDef.new()
	m.id = Ids.MODE_ESCAPE
	m.display_name = "Escape"
	m.description = "Scavenge enough scrap and crystal to assemble an escape ship and leave."
	m.kind = GameModeDef.Kind.ESCAPE
	m.escape_building_id = Ids.ESCAPE_SHIP
	m.starting_scrap = 35
	m.starting_crystal = 10
	m.rest_seconds = 24.0
	m.first_rest_seconds = 20.0
	return m


static func _endless() -> GameModeDef:
	var m := GameModeDef.new()
	m.id = Ids.MODE_ENDLESS
	m.display_name = "Endless"
	m.description = "No extraction. Waves scale forever. Chase a high score."
	m.kind = GameModeDef.Kind.ENDLESS
	m.relics_on_map = 6
	m.starting_scrap = 50
	m.starting_crystal = 20
	m.rest_seconds = 18.0
	m.first_rest_seconds = 15.0
	return m
