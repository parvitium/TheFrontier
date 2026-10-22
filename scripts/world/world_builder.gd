class_name WorldBuilder
extends RefCounted

const MAP_SIZE := 72.0


static func build(arena: Node3D) -> void:
	WorldLook.attach(arena, false)
	_ground(arena)
	_cover(arena)
	_dressing(arena)
	_core(arena)
	_resources(arena)
	_relics(arena)
	_spawns(arena)


static func _ground(arena: Node3D) -> void:
	var geo := arena.get_node("NavigationRegion3D/Geometry")
	Landscape.build(geo, true)


static func _cover(_arena: Node3D) -> void:
	pass


static func _dressing(arena: Node3D) -> void:
	for p in [Vector3(15, 0, 18), Vector3(-17, 0, -16), Vector3(10, 0, -21)]:
		var tank := VisualKit.instance("storage_tank")
		if tank:
			tank.position = Landscape.seat(p, 0.0, 0.08)
			arena.add_child(tank)


static func _core(arena: Node3D) -> void:
	var core := CoreEngine.new()
	core.name = "Core"
	core.position = Landscape.seat(Vector3.ZERO, 0.0, 0.03)
	arena.add_child(core)


static func _resources(arena: Node3D) -> void:
	var scrap_spots := [Vector3(10, 0, 6), Vector3(-11, 0, 8), Vector3(8, 0, -12), Vector3(-9, 0, -7), Vector3(16, 0, 14)]
	var crystal_spots := [Vector3(20, 0, -8), Vector3(-18, 0, 12), Vector3(6, 0, 22), Vector3(-22, 0, -14)]
	for i in scrap_spots.size():
		var node := ResourceNode.new()
		node.name = "Scrap_%d" % i
		node.position = Landscape.seat(scrap_spots[i], 0.0, 0.05)
		node.configure(Ids.SCRAP, 12, 0.4, Color(0.62, 0.38, 0.2), Color(0.7, 0.35, 0.1))
		arena.add_child(node)
	for i in crystal_spots.size():
		var node := ResourceNode.new()
		node.name = "Crystal_%d" % i
		node.position = Landscape.seat(crystal_spots[i], 0.0, 0.05)
		node.configure(Ids.CRYSTAL, 8, 0.65, Color(0.35, 0.78, 0.86), Color(0.3, 0.85, 1.0))
		arena.add_child(node)


static func _relics(arena: Node3D) -> void:
	if Session.mode.relics_on_map <= 0:
		return
	var spots := [
		Vector3(26, 0, 18), Vector3(-24, 0, 20), Vector3(22, 0, -24),
		Vector3(-28, 0, -18), Vector3(4, 0, 28), Vector3(-6, 0, -28),
	]
	var count: int = mini(spots.size(), Session.mode.relics_on_map)
	for i in count:
		var relic := Relic.new()
		relic.name = "Relic_%d" % i
		relic.position = Landscape.seat(spots[i], 0.0, 0.04)
		arena.add_child(relic)


static func _spawns(arena: Node3D) -> void:
	var holder := Node3D.new()
	holder.name = "SpawnPoints"
	arena.add_child(holder)
	var radius := 30.0
	for i in 8:
		var angle := TAU * float(i) / 8.0
		var marker := Marker3D.new()
		marker.name = "Spawn_%d" % i
		marker.position = Landscape.seat(Vector3(cos(angle) * radius, 0.0, sin(angle) * radius), 0.15)
		holder.add_child(marker)
