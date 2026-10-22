class_name PlacementRules
extends RefCounted

const CELL_SIZE := 2.0
const MAP_HALF_CELLS := 16
const CORE_RADIUS_CELLS := 1
const MAX_SLOPE_DEG := 28.0
const MAX_RELIEF := 1.05
const FOUNDATION_SINK := 0.03
const MAX_TILT_DEG := 18.0


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


static func footprint_center(origin: Vector2i, size: Vector2i) -> Vector3:
	var world := cell_to_world(origin, 0.0)
	world.x += float(size.x - 1) * CELL_SIZE * 0.5
	world.z += float(size.y - 1) * CELL_SIZE * 0.5
	return world


static func sample_footprint(building_id: String, origin: Vector2i) -> Dictionary:
	var def := BuildingCatalog.by_id(building_id)
	var size := Vector2i.ONE if def == null else def.footprint
	return sample_cells(origin, size)


static func sample_cells(origin: Vector2i, size: Vector2i) -> Dictionary:
	var min_y := INF
	var max_y := -INF
	var sum := 0.0
	var count := 0
	for cx in range(size.x):
		for cz in range(size.y):
			var center := cell_to_world(origin + Vector2i(cx, cz), 0.0)
			for sx in 3:
				for sz in 3:
					var x := center.x + (float(sx) - 1.0) * CELL_SIZE * 0.45
					var z := center.z + (float(sz) - 1.0) * CELL_SIZE * 0.45
					var y := Landscape.height_at(x, z)
					min_y = minf(min_y, y)
					max_y = maxf(max_y, y)
					sum += y
					count += 1
	var mid := footprint_center(origin, size)
	var slope := Landscape.slope_deg(mid.x, mid.z)
	return {
		min_y = min_y,
		max_y = max_y,
		avg_y = sum / float(maxi(1, count)),
		relief = max_y - min_y,
		slope_deg = slope,
		center = mid,
	}


static func seat_origin(building_id: String, origin: Vector2i) -> Vector3:
	var def := BuildingCatalog.by_id(building_id)
	var size := Vector2i.ONE if def == null else def.footprint
	return building_world_position(origin, size)


static func building_world_position(origin: Vector2i, footprint: Vector2i) -> Vector3:
	var sample := sample_cells(origin, footprint)
	var pos: Vector3 = sample.center
	pos.y = float(sample.avg_y) - FOUNDATION_SINK
	return pos


static func foundation_basis(x: float, z: float) -> Basis:
	var n := Landscape.normal_at(x, z)
	var ang := acos(clampf(n.y, -1.0, 1.0))
	var max_tilt := deg_to_rad(MAX_TILT_DEG)
	if ang > max_tilt and ang > 0.0001:
		n = n.lerp(Vector3.UP, 1.0 - max_tilt / ang).normalized()
	var ref := Vector3.FORWARD
	if absf(n.dot(ref)) > 0.94:
		ref = Vector3.RIGHT
	var x_axis := ref.cross(n).normalized()
	var z_axis := x_axis.cross(n).normalized()
	return Basis(x_axis, n, z_axis)


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
	var terrain := sample_cells(origin, def.footprint)
	if float(terrain.slope_deg) > MAX_SLOPE_DEG:
		return {ok = false, reason = "Ground too steep."}
	if float(terrain.relief) > MAX_RELIEF:
		return {ok = false, reason = "Ground too uneven."}
	return {ok = true, reason = "", cells = cells, terrain = terrain}
