class_name PlacementRules
extends RefCounted

const CELL_SIZE := 2.0
const MAP_HALF_CELLS := 16
const CORE_RADIUS_CELLS := 1


static func world_to_cell(world: Vector3) -> Vector2i:
	return Vector2i(int(round(world.x / CELL_SIZE)), int(round(world.z / CELL_SIZE)))


static func cell_to_world(cell: Vector2i, y: float = 0.0) -> Vector3:
	return Vector3(float(cell.x) * CELL_SIZE, y, float(cell.y) * CELL_SIZE)


static func is_in_map(cell: Vector2i) -> bool:
	return abs(cell.x) <= MAP_HALF_CELLS and abs(cell.y) <= MAP_HALF_CELLS


static func is_core_cell(cell: Vector2i) -> bool:
	return abs(cell.x) <= CORE_RADIUS_CELLS and abs(cell.y) <= CORE_RADIUS_CELLS


static func footprint_cells(building_id: String, origin: Vector2i) -> Array[Vector2i]:
	var def := BuildingCatalog.by_id(building_id)
	var size := Vector2i.ONE if def == null else def.footprint
	var cells: Array[Vector2i] = []
	for x in range(size.x):
		for y in range(size.y):
			cells.append(origin + Vector2i(x, y))
	return cells


static func evaluate(occupied: Dictionary, building_id: String, origin: Vector2i) -> Dictionary:
	var def := BuildingCatalog.by_id(building_id)
	if def == null:
		return {ok = false, reason = "Unknown building."}
	var cells := footprint_cells(building_id, origin)
	for cell in cells:
		if not is_in_map(cell):
			return {ok = false, reason = "Out of bounds."}
		if is_core_cell(cell):
			return {ok = false, reason = "Too close to the core."}
		if occupied.has(cell):
			return {ok = false, reason = "Cell occupied."}
	return {ok = true, reason = "", cells = cells}
