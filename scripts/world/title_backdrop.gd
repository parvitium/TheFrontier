class_name TitleBackdrop
extends RefCounted


static func build(root: Node3D) -> void:
	WorldLook.attach(root, true)
	_ground(root)
	_outpost(root)
	_turrets(root)
	_silhouettes(root)
	_haze(root)


static func _ground(root: Node3D) -> void:
	Landscape.build(root, true)


static func _outpost(root: Node3D) -> void:
	var core := VisualKit.instance("core_engine")
	if core:
		core.name = "TitleCore"
		root.add_child(core)
	var light := OmniLight3D.new()
	light.name = "CoreGlow"
	light.light_color = Color(1.0, 0.62, 0.22)
	light.light_energy = 4.2
	light.omni_range = 18.0
	light.position = Vector3(0, 3.2, 0)
	root.add_child(light)
	var wall_spots := [
		Vector3(4.2, 0, 4.6), Vector3(-4.6, 0, 3.8), Vector3(5.1, 0, -3.6), Vector3(-3.8, 0, -5.0),
		Vector3(7.2, 0, 0.6), Vector3(-7.0, 0, -0.8), Vector3(1.2, 0, 7.4), Vector3(-0.8, 0, -7.2),
		Vector3(9.4, 0, 2.8), Vector3(-9.0, 0, -2.4),
	]
	for i in wall_spots.size():
		var wall := VisualKit.instance("building_wall")
		if wall:
			wall.position = wall_spots[i]
			wall.rotate_y(float(i) * 0.55 + 0.15)
			root.add_child(wall)
	KitFactory.span_cable(root, wall_spots[0] + Vector3(0, 2.4, 0), wall_spots[4] + Vector3(0, 2.7, 0), "SpanCableA", 0.03)
	KitFactory.span_cable(root, wall_spots[1] + Vector3(0, 2.2, 0), wall_spots[5] + Vector3(0, 2.5, 0), "SpanCableB", 0.028)
	KitFactory.span_cable(root, wall_spots[2] + Vector3(0, 2.6, 0), wall_spots[8] + Vector3(0, 2.9, 0), "SpanCableC", 0.026)
	KitFactory.sandbag_stack(root, Vector3(2.4, 0.0, 5.2), 0.4, 6, 77)
	KitFactory.sandbag_stack(root, Vector3(-5.4, 0.0, 2.2), -0.6, 5, 88)
	var tank_spots := [Vector3(11, 0, -6), Vector3(-13, 0, 5), Vector3(14, 0, 9)]
	for p in tank_spots:
		var tank := VisualKit.instance("storage_tank")
		if tank:
			tank.position = p
			root.add_child(tank)
	var ship := VisualKit.instance("building_escape_ship")
	if ship:
		ship.position = Vector3(-9, 0, -11)
		ship.rotate_y(0.7)
		root.add_child(ship)
	var beacon := VisualKit.instance("building_repair_beacon")
	if beacon:
		beacon.position = Vector3(5.5, 0, -3)
		root.add_child(beacon)


static func _turrets(root: Node3D) -> void:
	var tracker := TitleTurretRig.new()
	tracker.name = "TurretRig"
	root.add_child(tracker)
	for p in [Vector3(7, 0, 7), Vector3(-7, 0, 6), Vector3(3, 0, -8)]:
		var turret := VisualKit.instance("building_turret")
		if turret:
			turret.position = p
			tracker.add_child(turret)


static func _silhouettes(root: Node3D) -> void:
	var pack := TitleSilhouettes.new()
	pack.name = "Silhouettes"
	root.add_child(pack)
	var kinds := ["mob_rusher", "mob_ranger", "mob_tank", "mob_rusher", "mob_ranger"]
	for i in kinds.size():
		var mob := VisualKit.instance(kinds[i])
		if mob:
			var angle := TAU * float(i) / float(kinds.size())
			mob.position = Vector3(cos(angle) * 26.0, 0, sin(angle) * 26.0)
			pack.add_child(mob)


static func _haze(root: Node3D) -> void:
	var dust := GPUParticles3D.new()
	dust.name = "Haze"
	dust.amount = 48
	dust.lifetime = 8.0
	dust.preprocess = 4.0
	dust.visibility_aabb = AABB(Vector3(-40, 0, -40), Vector3(80, 16, 80))
	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proc.emission_box_extents = Vector3(32, 2, 32)
	proc.gravity = Vector3(0, 0.04, 0)
	proc.initial_velocity_min = 0.05
	proc.initial_velocity_max = 0.2
	proc.direction = Vector3(0.4, 0.1, 0.2)
	proc.spread = 20.0
	proc.scale_min = 0.08
	proc.scale_max = 0.22
	proc.color = Color(0.85, 0.55, 0.32, 0.35)
	dust.process_material = proc
	var draw := SphereMesh.new()
	draw.radius = 0.12
	draw.height = 0.24
	draw.radial_segments = 6
	draw.rings = 3
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.8, 0.5, 0.28, 0.18)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	draw.material = mat
	dust.draw_pass_1 = draw
	dust.position.y = 1.4
	root.add_child(dust)


class TitleTurretRig:
	extends Node3D
	var _t: float = 0.0

	func _process(delta: float) -> void:
		_t += delta * 0.35
		var target := Vector3(cos(_t) * 18.0, 1.4, sin(_t * 0.8) * 16.0)
		for child in get_children():
			var head := VisualKit.find_node(child, "Head")
			if head and is_instance_valid(head):
				var look := target
				look.y = head.global_position.y
				var dir := look - head.global_position
				if dir.length() > 0.2 and absf(dir.normalized().dot(Vector3.UP)) < 0.95:
					head.look_at(look, Vector3.UP)


class TitleSilhouettes:
	extends Node3D
	var _t: float = 0.0

	func _process(delta: float) -> void:
		_t += delta * 0.22
		var i := 0
		for child in get_children():
			if child is Node3D:
				var n: Node3D = child as Node3D
				var base := TAU * float(i) / maxf(1.0, float(get_child_count()))
				var radius := 25.0 + sin(_t + float(i)) * 1.5
				n.position = Vector3(cos(base + _t) * radius, 0.0, sin(base + _t) * radius)
				var ahead := Vector3(cos(base + _t + 0.2) * radius, 0, sin(base + _t + 0.2) * radius)
				if (ahead - n.position).length() > 0.05:
					n.look_at(ahead, Vector3.UP)
			i += 1
