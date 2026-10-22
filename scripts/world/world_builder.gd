class_name WorldBuilder
extends RefCounted

const MAP_SIZE := 72.0


static func build(arena: Node3D) -> void:
	_lighting(arena)
	_ground(arena)
	_cover(arena)
	_core(arena)
	_resources(arena)
	_relics(arena)
	_spawns(arena)


static func _lighting(arena: Node3D) -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-48, 42, 0)
	sun.light_color = Color(1.0, 0.78, 0.58)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	arena.add_child(sun)
	var env := WorldEnvironment.new()
	env.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.08, 0.1, 0.14)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.22, 0.28, 0.36)
	environment.ambient_light_energy = 0.55
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.16, 0.2, 0.26)
	environment.fog_density = 0.008
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.glow_enabled = true
	environment.glow_intensity = 0.35
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.12, 0.18, 0.28)
	sky_mat.sky_horizon_color = Color(0.62, 0.32, 0.18)
	sky_mat.ground_bottom_color = Color(0.05, 0.06, 0.07)
	sky_mat.ground_horizon_color = Color(0.28, 0.16, 0.1)
	sky_mat.sun_angle_max = 18.0
	sky.sky_material = sky_mat
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	env.environment = environment
	arena.add_child(env)


static func _ground(arena: Node3D) -> void:
	var geo := arena.get_node("NavigationRegion3D/Geometry")
	var ground_mat := Greybox.material(Color(0.22, 0.24, 0.2), Color.BLACK, 0.0, 0.0, 0.92)
	Greybox.static_box(geo, Vector3(MAP_SIZE, 1.0, MAP_SIZE), Vector3(0, -0.5, 0), ground_mat, "Ground", 1)
	var cliff := Greybox.material(Color(0.16, 0.17, 0.18), Color.BLACK, 0.0, 0.05, 0.88)
	var half := MAP_SIZE * 0.5 + 1.5
	Greybox.static_box(geo, Vector3(MAP_SIZE + 4, 6, 3), Vector3(0, 2.5, half), cliff, "CliffN", 1)
	Greybox.static_box(geo, Vector3(MAP_SIZE + 4, 6, 3), Vector3(0, 2.5, -half), cliff, "CliffS", 1)
	Greybox.static_box(geo, Vector3(3, 6, MAP_SIZE + 4), Vector3(half, 2.5, 0), cliff, "CliffE", 1)
	Greybox.static_box(geo, Vector3(3, 6, MAP_SIZE + 4), Vector3(-half, 2.5, 0), cliff, "CliffW", 1)


static func _cover(arena: Node3D) -> void:
	var geo := arena.get_node("NavigationRegion3D/Geometry")
	var rock := Greybox.material(Color(0.3, 0.31, 0.29), Color.BLACK, 0.0, 0.05, 0.86)
	var spots := [
		Vector3(12, 0.7, 8), Vector3(-14, 0.9, 11), Vector3(18, 0.6, -16),
		Vector3(-20, 0.8, -12), Vector3(8, 0.5, -22), Vector3(-9, 0.7, 20),
		Vector3(24, 0.8, 6), Vector3(-26, 0.6, -4),
	]
	for i in spots.size():
		var p: Vector3 = spots[i]
		Greybox.static_box(geo, Vector3(2.4 + i % 2, 1.4 + (i % 3) * 0.3, 1.8), p, rock, "Cover_%d" % i, 1)


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
	if Session.mode.kind != GameModeDef.Kind.GATHER:
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
