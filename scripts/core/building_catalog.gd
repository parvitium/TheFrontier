class_name BuildingCatalog
extends RefCounted


static func all() -> Array[BuildingDef]:
	var list: Array[BuildingDef] = []
	list.append(_make(Ids.WALL, "Wall", 8, 0, 80.0, Vector2i.ONE, true, true, "Blocks mob pathing.", Color(0.45, 0.5, 0.58)))
	list.append(_make(Ids.TURRET, "Auto-Turret", 25, 10, 60.0, Vector2i.ONE, true, true, "Fires on the nearest mob.", Color(0.35, 0.72, 0.78)))
	list.append(_make(Ids.TRAP, "Spike Field", 12, 5, 40.0, Vector2i.ONE, false, true, "Slows and damages mobs that cross it.", Color(0.78, 0.32, 0.28)))
	list.append(_make(Ids.REPAIR, "Repair Beacon", 20, 15, 50.0, Vector2i.ONE, true, true, "Repairs the core and nearby buildings.", Color(0.38, 0.78, 0.48)))
	list.append(_make(Ids.ESCAPE_SHIP, "Escape Ship", 80, 40, 200.0, Vector2i(2, 2), true, false, "Build this to leave the planet.", Color(0.95, 0.78, 0.28)))
	return list


static func by_id(id: String) -> BuildingDef:
	for def in all():
		if def.id == id:
			return def
	return null


static func available_for_mode(mode: GameModeDef) -> Array[BuildingDef]:
	var list: Array[BuildingDef] = []
	for def in all():
		if def.buildable_in_all_modes:
			list.append(def)
		elif mode != null and mode.kind == GameModeDef.Kind.ESCAPE and def.id == mode.escape_building_id:
			list.append(def)
	return list


static func _make(id: String, name: String, scrap: int, crystal: int, hp: float, footprint: Vector2i, blocks: bool, always: bool, desc: String, color: Color) -> BuildingDef:
	var def := BuildingDef.new()
	def.id = id
	def.display_name = name
	def.scrap_cost = scrap
	def.crystal_cost = crystal
	def.max_health = hp
	def.footprint = footprint
	def.blocks_navigation = blocks
	def.buildable_in_all_modes = always
	def.description = desc
	def.color = color
	return def
