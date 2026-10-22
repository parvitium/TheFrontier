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
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(MAP_SIZE, MAP_SIZE)
	mesh.subdivide_width = 24
	mesh.subdivide_depth = 24
	var visual := MeshInstance3D.new()
	visual.name = "Terrain"
	visual.mesh = mesh
	visual.material_override = PbrLibrary.terrain()
	geo.add_child(visual)
	var body := StaticBody3D.new()
	body.name = "Ground"
	body.collision_layer = 1
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(MAP_SIZE, 1.0, MAP_SIZE)
	col.shape = shape
	col.position.y = -0.5
	body.add_child(col)
	geo.add_child(body)
	var rock_mat := PbrLibrary.rock(Color(0.85, 0.82, 0.78))
	var half := MAP_SIZE * 0.5 + 1.8
	_cliff(geo, Vector3(MAP_SIZE + 4, 7.5, 4.2), Vector3(0, 3.2, half), rock_mat, "CliffN")
	_cliff(geo, Vector3(MAP_SIZE + 4, 7.5, 4.2), Vector3(0, 3.2, -half), rock_mat, "CliffS")
	_cliff(geo, Vector3(4.2, 7.5, MAP_SIZE + 4), Vector3(half, 3.2, 0), rock_mat, "CliffE")
	_cliff(geo, Vector3(4.2, 7.5, MAP_SIZE + 4), Vector3(-half, 3.2, 0), rock_mat, "CliffW")


static func _cliff(parent: Node3D, size: Vector3, position: Vector3, mat: Material, name: String) -> void:
	var body := StaticBody3D.new()
	body.name = name
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = position
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	parent.add_child(body)
	var along := size.x if size.x >= size.z else size.z
	var count := 11
	for i in count:
		var t := (float(i) / float(count - 1) - 0.5) * along * 0.92
		var offset := Vector3(t, 0, 0) if size.x >= size.z else Vector3(0, 0, t)
		var inst := VisualKit.instance(["rock_a", "rock_b", "rock_c"][i % 3])
		if inst:
			var ground := Vector3(position.x, 0.0, position.z) + offset
			inst.position = ground
			var s := 2.8 + float(i % 3) * 0.55
			inst.scale = Vector3(s, 3.4 + float(i % 2) * 1.1, s)
			inst.rotate_y(float(i) * 0.73)
			parent.add_child(inst)
		elif i == 0:
			Greybox.static_box(parent, size, position, mat, "%s_vis" % name, 1)


static func _cover(arena: Node3D) -> void:
	var geo := arena.get_node("NavigationRegion3D/Geometry")
	var spots := [
		Vector3(12, 0, 8), Vector3(-14, 0, 11), Vector3(18, 0, -16),
		Vector3(-20, 0, -12), Vector3(8, 0, -22), Vector3(-9, 0, 20),
		Vector3(24, 0, 6), Vector3(-26, 0, -4),
	]
	var rocks := ["rock_a", "rock_b", "rock_c"]
	for i in spots.size():
		var p: Vector3 = spots[i]
		var inst := VisualKit.instance(rocks[i % rocks.size()])
		if inst:
			inst.position = p
			inst.rotate_y(float(i) * 0.55)
			inst.scale = Vector3(1.2 + float(i % 3) * 0.15, 1.0 + float(i % 2) * 0.2, 1.15)
			geo.add_child(inst)
			var body := StaticBody3D.new()
			body.name = "Cover_%d" % i
			body.collision_layer = 1
			body.collision_mask = 0
			body.position = p + Vector3(0, 0.7, 0)
			var col := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(2.2, 1.4, 1.8)
			col.shape = shape
			body.add_child(col)
			geo.add_child(body)
		else:
			Greybox.static_box(geo, Vector3(2.4, 1.4, 1.8), p + Vector3(0, 0.7, 0), PbrLibrary.rock(), "Cover_%d" % i, 1)


static func _dressing(arena: Node3D) -> void:
	for p in [Vector3(15, 0, 18), Vector3(-17, 0, -16)]:
		var tank := VisualKit.instance("storage_tank")
		if tank:
			tank.position = p
			arena.add_child(tank)


static func _core(arena: Node3D) -> void:
	var core := CoreEngine.new()
	core.name = "Core"
	core.position = Vector3(0, 0, 0)
	arena.add_child(core)


static func _resources(arena: Node3D) -> void:
	var scrap_spots := [Vector3(10, 0, 6), Vector3(-11, 0, 8), Vector3(8, 0, -12), Vector3(-9, 0, -7), Vector3(16, 0, 14)]
	var crystal_spots := [Vector3(20, 0, -8), Vector3(-18, 0, 12), Vector3(6, 0, 22), Vector3(-22, 0, -14)]
	for i in scrap_spots.size():
		var node := ResourceNode.new()
		node.name = "Scrap_%d" % i
		node.position = scrap_spots[i]
		node.configure(Ids.SCRAP, 12, 0.4, Color(0.62, 0.38, 0.2), Color(0.7, 0.35, 0.1))
		arena.add_child(node)
	for i in crystal_spots.size():
		var node := ResourceNode.new()
		node.name = "Crystal_%d" % i
		node.position = crystal_spots[i]
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
		relic.position = spots[i]
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
		marker.position = Vector3(cos(angle) * radius, 0.1, sin(angle) * radius)
		holder.add_child(marker)
