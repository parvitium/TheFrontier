class_name BreachRules
extends RefCounted

## Grid reachability for the core. Walls (and other nav-blocking buildings)
## may fully enclose the core — placement is allowed so walls stay meaningful.
## Traps occupy a cell for placement but are passable: the flood walks through
## them. When the core is unreachable, mobs path to the solid frontier cells
## and attack those buildings.


static func core_reachable(occupied: Dictionary, from: Vector2i, instances: Dictionary = {}) -> bool:
	var reach := flood(occupied, from, instances)
	for cell in _core_cells():
		if reach.has(cell):
			return true
	return false


static func blocking_serials(occupied: Dictionary, from: Vector2i, instances: Dictionary = {}) -> Array[int]:
	var reach := flood(occupied, from, instances)
	for cell in _core_cells():
		if reach.has(cell):
			return []
	var found: Dictionary = {}
	for key in reach.keys():
		var cell: Vector2i = key
		for n in _neighbors(cell):
			if cell_blocks(occupied, n, instances):
				found[int(occupied[n])] = true
	var serials: Array[int] = []
	for key in found.keys():
		serials.append(int(key))
	return serials


static func flood(occupied: Dictionary, from: Vector2i, instances: Dictionary = {}) -> Dictionary:
	var seen: Dictionary = {}
	if not PlacementRules.is_in_map(from) or cell_blocks(occupied, from, instances):
		return seen
	var queue: Array[Vector2i] = [from]
	seen[from] = true
	var i := 0
	while i < queue.size():
		var cell: Vector2i = queue[i]
		i += 1
		for n in _neighbors(cell):
			if seen.has(n):
				continue
			if not PlacementRules.is_in_map(n):
				continue
			if cell_blocks(occupied, n, instances):
				continue
			seen[n] = true
			queue.append(n)
	return seen


static func cell_blocks(occupied: Dictionary, cell: Vector2i, instances: Dictionary = {}) -> bool:
	if not occupied.has(cell):
		return false
	if instances.is_empty():
		return true
	var serial := int(occupied[cell])
	if not instances.has(serial):
		return true
	var info: Variant = instances[serial]
	var building_id := ""
	if typeof(info) == TYPE_DICTIONARY:
		building_id = str(info.get("id", ""))
	else:
		building_id = str(info)
	var def := BuildingCatalog.by_id(building_id)
	if def == null:
		return true
	return def.blocks_navigation


static func _core_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var r := PlacementRules.CORE_RADIUS_CELLS
	for x in range(-r, r + 1):
		for y in range(-r, r + 1):
			cells.append(Vector2i(x, y))
	return cells


static func _neighbors(cell: Vector2i) -> Array[Vector2i]:
	return [
		cell + Vector2i(1, 0),
		cell + Vector2i(-1, 0),
		cell + Vector2i(0, 1),
		cell + Vector2i(0, -1),
	]
