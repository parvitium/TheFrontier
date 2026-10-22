class_name BuildingFactory
extends RefCounted


static func spawn(arena: Arena, building_id: String, origin: Vector2i, serial: int = -1) -> BuildingBase:
	var def := BuildingCatalog.by_id(building_id)
	if def == null:
		return null
	var building := _make(building_id)
	building.name = "%s_%d_%d" % [building_id, origin.x, origin.y]
	var parent: Node = arena.obstacle_root() if def.blocks_navigation else arena
	parent.add_child(building)
	building.setup(def, origin, serial)
	return building


static func _make(building_id: String) -> BuildingBase:
	match building_id:
		Ids.WALL:
			return WallBuilding.new()
		Ids.TURRET:
			return TurretBuilding.new()
		Ids.TRAP:
			return TrapBuilding.new()
		Ids.REPAIR:
			return RepairBeacon.new()
		Ids.ESCAPE_SHIP:
			return EscapeShip.new()
	return BuildingBase.new()
