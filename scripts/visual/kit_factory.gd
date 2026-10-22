class_name KitFactory
extends RefCounted

## Runtime sci-fi / badlands kit. Named nodes keep VisualKit / combat hooks working.

static var _wall_seq: int = 0
static var _proto: Dictionary = {}
static var _mesh_cache: Dictionary = {}


static func build(slot: String) -> Node3D:
	match slot:
		"core_engine":
			return _proto_dup("core_engine", _core)
		"building_wall":
			var variant := _wall_seq % 4
			_wall_seq += 1
			return _proto_dup("wall_%d" % variant, _make_wall.bind(variant))
		"building_turret":
			return _proto_dup("building_turret", _turret)
		"building_trap":
			return _proto_dup("building_trap", _trap)
		"building_repair_beacon":
			return _proto_dup("building_repair_beacon", _beacon)
		"building_escape_ship":
			return _proto_dup("building_escape_ship", _ship)
		"storage_tank":
			return _proto_dup("storage_tank", _tank)
		"pulse_rifle":
			return _proto_dup("pulse_rifle", _rifle)
		"scatter_cannon":
			return _proto_dup("scatter_cannon", _shotgun)
		"rock_a":
			return _rock(11, Vector3(0.95, 0.55, 0.82))
		"rock_b":
			return _rock(27, Vector3(1.15, 0.48, 0.95))
		"rock_c":
			return _rock(43, Vector3(0.78, 0.42, 1.05))
		_:
			return null


static func warmup() -> void:
	var t0 := Time.get_ticks_msec()
	for slot in ["core_engine", "storage_tank", "building_turret", "building_trap", "pulse_rifle", "scatter_cannon"]:
		var node := build(slot)
		if node:
			node.free()
	for _i in 4:
		var wall := build("building_wall")
		if wall:
			wall.free()
	print("KIT WARMUP_MS=", Time.get_ticks_msec() - t0)


static func _proto_dup(key: String, builder: Callable) -> Node3D:
	if not _proto.has(key):
		_proto[key] = builder.call()
	return (_proto[key] as Node3D).duplicate()


static func pebble_mesh() -> ArrayMesh:
	var baked := load_baked_mesh("pebble")
	if baked:
		return baked
	return boulder_mesh(91, Vector3(1.0, 0.42, 1.0), 8, 6)


static func cover_boulder_mesh(kind: int) -> ArrayMesh:
	var i: int = clampi(kind, 0, 2)
	var baked := load_baked_mesh("boulder_%d" % i)
	if baked:
		return baked
	var seeds: Array[int] = [11, 27, 43]
	var scales: Array[Vector3] = [
		Vector3(1.15, 0.38, 0.82),
		Vector3(1.35, 0.32, 0.95),
		Vector3(0.92, 0.36, 1.18),
	]
	return boulder_mesh(seeds[i], scales[i], 14, 9)


static func load_baked_mesh(stem: String) -> ArrayMesh:
	var path := "res://assets/baked/%s.res" % stem
	if ResourceLoader.exists(path):
		return load(path) as ArrayMesh
	return null


static func scrub_mesh() -> ArrayMesh:
	if _mesh_cache.has("scrub"):
		return _mesh_cache["scrub"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 19
	for i in 7:
		var ang := float(i) / 7.0 * TAU + rng.randf_range(-0.2, 0.2)
		var h := rng.randf_range(0.22, 0.55)
		var w := rng.randf_range(0.025, 0.05)
		var lean := rng.randf_range(-0.18, 0.18)
		var base := Vector3(cos(ang) * 0.04, 0.0, sin(ang) * 0.04)
		var tip := Vector3(cos(ang) * (0.08 + lean), h, sin(ang) * (0.08 + lean))
		var side := Vector3(-sin(ang) * w, 0, cos(ang) * w)
		_tri(st, base - side, base + side, tip)
		_tri(st, base + side, base - side, tip + Vector3(0, -0.02, 0))
	st.generate_normals()
	var mesh := st.commit()
	_mesh_cache["scrub"] = mesh
	return mesh


static func _core() -> Node3D:
	var root := Node3D.new()
	root.name = "core_engine"
	# Grounded foundation: wide pad, ring, bolts, buried slightly.
	_cyl(root, "Foundation", 2.65, 0.28, Vector3(0, 0.04, 0), "Concrete", 20)
	_cyl(root, "FoundationLip", 2.72, 0.06, Vector3(0, 0.18, 0), "Tread", 20)
	var dust := MeshInstance3D.new()
	dust.name = "FoundationDust"
	var dust_mesh := CylinderMesh.new()
	dust_mesh.top_radius = 3.4
	dust_mesh.bottom_radius = 3.8
	dust_mesh.height = 0.08
	dust.mesh = dust_mesh
	dust.position = Vector3(0, 0.02, 0)
	dust.material_override = PbrLibrary.dust()
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(dust)
	_cyl(root, "PadInset", 2.15, 0.05, Vector3(0, 0.16, 0), "Tread", 16)
	for i in 8:
		var a := float(i) / 8.0 * TAU
		_cyl(root, "PadBolt%d" % i, 0.07, 0.08, Vector3(cos(a) * 2.35, 0.2, sin(a) * 2.35), "Rust", 8)
		_box(root, "Cable%d" % i, Vector3(0.08, 0.06, 0.55), Vector3(cos(a) * 1.9, 0.18, sin(a) * 1.9), "Rust", Vector3(0, a, 0))
	_cyl(root, "Pedestal", 1.42, 0.85, Vector3(0, 0.58, 0), "Concrete", 18)
	_cyl(root, "Ring", 1.58, 0.14, Vector3(0, 1.02, 0), "Oxidized", 18)
	_cyl(root, "Collar", 0.62, 0.22, Vector3(0, 1.16, 0), "DarkMetal", 14)
	_cyl(root, "Coil", 0.4, 2.05, Vector3(0, 2.2, 0), "Oxidized", 16)
	for i in 6:
		var a := float(i) / 6.0 * TAU
		_box(root, "Fin%d" % i, Vector3(0.07, 1.55, 0.42), Vector3(cos(a) * 0.62, 2.15, sin(a) * 0.62), "Oxidized", Vector3(0, a, 0))
	for i in 8:
		var a := float(i) / 8.0 * TAU
		_box(root, "Strip%d" % i, Vector3(0.05, 1.35, 0.05), Vector3(cos(a) * 0.44, 2.15, sin(a) * 0.44), "EmissiveCyan")
	for i in 3:
		var a: float = [0.4, 2.2, 4.0][i]
		_cyl(root, "Pipe%d" % i, 0.07, 1.6, Vector3(cos(a) * 1.2, 1.35, sin(a) * 1.2), "Rust", 8)
		_sphere(root, "Elbow%d" % i, 0.1, Vector3(cos(a) * 1.2, 2.15, sin(a) * 1.2), "Rust", 8)
	var heart := _sphere(root, "Heart", 0.58, Vector3(0, 3.32, 0), "EmissiveAmber", 20)
	heart.name = "Heart"
	_cyl(root, "Cap", 0.5, 0.14, Vector3(0, 3.9, 0), "Oxidized", 14)
	compact(root)
	return root


static func _make_wall(variant: int) -> Node3D:
	var hull_h: float = [1.62, 2.52, 1.28, 2.08][variant]
	var root := Node3D.new()
	root.name = "wall"
	_box(root, "Plinth", Vector3(2.42, 0.22, 2.28), Vector3(0.02, 0.08, 0.04), "Concrete")
	_box(root, "PlinthBevel", Vector3(2.18, 0.08, 2.08), Vector3(0.0, 0.20, 0.02), "Concrete")
	_box(root, "PlinthLip", Vector3(2.48, 0.04, 2.34), Vector3(0.0, 0.22, 0.03), "Tread")
	_box(root, "HullBoot", Vector3(1.96, 0.32, 1.88), Vector3(0.02, 0.38, 0.0), "Concrete")
	_box(root, "Hull", Vector3(1.64, hull_h - 0.22, 1.56), Vector3(0.0, 0.42 + (hull_h - 0.22) * 0.5, 0.0), "Concrete")
	_box(root, "HullCrown", Vector3(1.46, 0.12, 1.40), Vector3(0.0, 0.26 + hull_h - 0.02, 0.0), "Concrete")
	_box(root, "HullChamferX", Vector3(1.78, 0.06, 1.36), Vector3(0, 0.26 + hull_h - 0.01, 0), "Concrete")
	_box(root, "HullChamferZ", Vector3(1.36, 0.06, 1.72), Vector3(0, 0.26 + hull_h - 0.01, 0), "Concrete")
	var mid_y := 0.26 + hull_h * 0.5
	var top_y := 0.26 + hull_h
	for i in 4:
		var a := float(i) * PI * 0.5 + PI * 0.25
		_box(root, "HullBevel%d" % i, Vector3(0.16, hull_h * 0.88, 0.16), Vector3(cos(a) * 0.94, mid_y, sin(a) * 0.90), "Concrete", Vector3(0.0, a, 0.0))
	_box(root, "Buttress0", Vector3(0.22, hull_h * 0.82, 0.62), Vector3(0.02, 0.48, 1.18), "Concrete", Vector3(0.46, 0.0, 0.0))
	_box(root, "ButtressFoot", Vector3(0.42, 0.14, 0.78), Vector3(0.02, 0.16, 1.32), "Concrete")
	if variant == 1 or variant == 3:
		_box(root, "Annex", Vector3(0.78, hull_h * 0.52, 0.66), Vector3(1.18, 0.28 + hull_h * 0.26, 0.12), "Concrete")
		_box(root, "AnnexRoof", Vector3(0.92, 0.05, 0.78), Vector3(1.18, 0.28 + hull_h * 0.54, 0.12), "Corrugated", Vector3(0.0, 0.0, 0.18))
	var faces: Array[Vector3] = [
		Vector3(0, mid_y, 0.86), Vector3(0, 0, 0),
		Vector3(0, mid_y, -0.86), Vector3(0, PI, 0),
		Vector3(0.86, mid_y, 0), Vector3(0, -PI * 0.5, 0),
		Vector3(-0.86, mid_y, 0), Vector3(0, PI * 0.5, 0),
	]
	for i in 4:
		var pos: Vector3 = faces[i * 2]
		var rot: Vector3 = faces[i * 2 + 1]
		var panel_mat := "Corrugated" if (i + variant) % 2 == 0 else "PaintedMetal"
		_box(root, "Frame%d" % i, Vector3(1.52, hull_h * 0.88, 0.07), pos, "DarkMetal", rot)
		_box(root, "PanelA%d" % i, Vector3(0.62, hull_h * 0.68, 0.06), pos + Vector3(-0.36, 0.02, 0.04).rotated(Vector3.UP, rot.y), panel_mat, rot)
		_box(root, "PanelB%d" % i, Vector3(0.62, hull_h * 0.62, 0.06), pos + Vector3(0.36, -0.04, 0.04).rotated(Vector3.UP, rot.y), panel_mat if variant != 2 else "Rust", rot)
		_box(root, "PanelInsetA%d" % i, Vector3(0.46, hull_h * 0.42, 0.035), pos + Vector3(-0.36, 0.06, 0.07).rotated(Vector3.UP, rot.y), "DarkMetal", rot)
		if variant != 2 or i != 1:
			_box(root, "PanelInsetB%d" % i, Vector3(0.46, hull_h * 0.38, 0.035), pos + Vector3(0.36, 0.0, 0.07).rotated(Vector3.UP, rot.y), "Oxidized", rot)
		_box(root, "Wear%d" % i, Vector3(0.5, 0.28, 0.05), pos + Vector3(0.42 if i % 2 == 0 else -0.34, -hull_h * 0.26, 0.05).rotated(Vector3.UP, rot.y), "Rust", rot)
		for r in 4:
			var rv := Vector3(-0.54 + float(r % 2) * 0.38, hull_h * (0.16 if r < 2 else -0.2), 0.085)
			_cyl(root, "Rivet%d_%d" % [i, r], 0.016, 0.028, pos + rv.rotated(Vector3.UP, rot.y), "Oxidized", 6, rot)
	for i in 4:
		var a := float(i) * PI * 0.5 + PI * 0.25
		_box(root, "Trim%d" % i, Vector3(0.12, hull_h + 0.22, 0.12), Vector3(cos(a) * 1.02, mid_y + 0.04, sin(a) * 0.98), "Oxidized")
		_cyl(root, "CornerPost%d" % i, 0.065, hull_h + 0.22, Vector3(cos(a) * 1.06, mid_y + 0.02, sin(a) * 1.02), "DarkMetal", 8)
		_box(root, "Brace%d" % i, Vector3(0.09, hull_h * 0.78, 0.09), Vector3(cos(a) * 1.16, 0.52, sin(a) * 1.12), "Oxidized", Vector3(0.0, a, 0.48 if i % 2 == 0 else -0.48))
	if variant == 1 or variant == 3:
		_box(root, "Roof", Vector3(2.22, 0.06, 2.42), Vector3(0.0, top_y + 0.26, 0.14), "Corrugated", Vector3(0.28, 0.0, 0.0))
		_box(root, "RoofUnder", Vector3(2.0, 0.05, 2.05), Vector3(0.0, top_y + 0.08, 0.0), "DarkMetal")
	else:
		_box(root, "Roof", Vector3(1.18, 0.07, 2.24), Vector3(-0.44, top_y + 0.36, 0.0), "Corrugated", Vector3(0.0, 0.0, 0.46))
		_box(root, "RoofB", Vector3(1.18, 0.07, 2.24), Vector3(0.44, top_y + 0.36, 0.0), "Corrugated", Vector3(0.0, 0.0, -0.46))
		_box(root, "Ridge", Vector3(0.1, 0.08, 2.26), Vector3(0.0, top_y + 0.58, 0.0), "Oxidized")
	_box(root, "RoofVent", Vector3(0.34, 0.18, 0.34), Vector3(0.32, top_y + 0.52, 0.18), "DarkMetal")
	_box(root, "RoofPipe", Vector3(0.08, 0.52, 0.08), Vector3(-0.48, top_y + 0.58, 0.32), "Rust")
	var ant_h: float = [0.85, 1.55, 0.55, 1.15][variant]
	_cyl(root, "Antenna", 0.026, ant_h, Vector3(0.62, top_y + 0.52 + ant_h * 0.5, -0.45), "Oxidized", 6)
	_cyl(root, "AntennaTip", 0.012, 0.16, Vector3(0.62, top_y + 0.52 + ant_h + 0.08, -0.45), "EmissiveAmber", 6)
	_box(root, "AntennaArm", Vector3(0.42, 0.035, 0.035), Vector3(0.42, top_y + 0.82, -0.45), "DarkMetal")
	sandbag_stack(root, Vector3(0.0, 0.12, 1.18), 0.0, 5 if variant == 2 else 3, 20 + variant)
	if variant != 1:
		sandbag_stack(root, Vector3(-1.12, 0.12, 0.32), PI * 0.5, 3, 40 + variant)
	_box(root, "Vent", Vector3(0.66, 0.36, 0.07), Vector3(0, mid_y + hull_h * 0.16, 0.96), "DarkMetal")
	for i in 3:
		_box(root, "Slat%d" % i, Vector3(0.58, 0.03, 0.03), Vector3(0, mid_y + hull_h * 0.04 + float(i) * 0.085, 1.01), "Corrugated")
	_box(root, "LiteL", Vector3(0.28, 0.06, 0.06), Vector3(-0.46, top_y - 0.12, 0.96), "EmissiveCyan")
	_box(root, "LiteR", Vector3(0.28, 0.06, 0.06), Vector3(0.46, top_y - 0.12, 0.96), "EmissiveCyan")
	_box(root, "DoorRecess", Vector3(0.72, hull_h * 0.58, 0.08), Vector3(0.02, 0.38 + hull_h * 0.22, 0.90), "DarkMetal")
	_box(root, "DoorLeaf", Vector3(0.58, hull_h * 0.50, 0.04), Vector3(0.02, 0.38 + hull_h * 0.20, 0.96), "PaintedMetal")
	_box(root, "Lintel", Vector3(0.92, 0.08, 0.14), Vector3(0.02, 0.38 + hull_h * 0.54, 0.94), "Oxidized")
	_box(root, "Clapboard0", Vector3(1.48, 0.10, 0.05), Vector3(0.0, mid_y - hull_h * 0.18, 0.92), "Corrugated")
	_box(root, "Clapboard1", Vector3(1.40, 0.10, 0.05), Vector3(0.04, mid_y - hull_h * 0.08, 0.94), "Corrugated")
	_box(root, "Sill", Vector3(0.86, 0.06, 0.16), Vector3(-0.02, 0.34, 1.02), "Concrete")
	_box(root, "Downspout", Vector3(0.05, hull_h * 0.72, 0.05), Vector3(0.92, mid_y - 0.08, 0.88), "Rust")
	span_cable(root, Vector3(-0.9, top_y + 0.15, 0.9), Vector3(-1.15, 0.18, 1.15), "Cable0", 0.018)
	span_cable(root, Vector3(0.85, top_y + 0.2, -0.7), Vector3(1.2, 0.2, -1.05), "Cable1", 0.016)
	_cyl(root, "BaseDust", 1.55, 0.06, Vector3(0.0, 0.03, 0.0), "Sand", 10)
	for i in 4:
		var a := float(i) * PI * 0.5
		span_cable(root, Vector3(cos(a) * 0.72, mid_y + 0.2, sin(a) * 0.7), Vector3(cos(a) * 0.72, mid_y - 0.35, sin(a) * 0.7), "Weld%d" % i, 0.012)
		_box(root, "Gusset%d" % i, Vector3(0.18, 0.08, 0.34), Vector3(cos(a) * 0.92, 0.34, sin(a) * 0.88), "Oxidized", Vector3(0.0, a, 0.0))
		_box(root, "Stencil%d" % i, Vector3(0.18, 0.12, 0.01), faces[i * 2] + Vector3(0.32, hull_h * 0.18, 0.055).rotated(Vector3.UP, faces[i * 2 + 1].y), "PaintedMetal", faces[i * 2 + 1])
	compact(root)
	return root


static func sandbag_stack(parent: Node, origin: Vector3, yaw: float, count: int, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in count:
		var col := i % 3
		var row := i / 3
		var local := Vector3(float(col - 1) * 0.42 + rng.randf_range(-0.04, 0.04), 0.1 + float(row) * 0.18, rng.randf_range(-0.04, 0.05))
		var world := origin + local.rotated(Vector3.UP, yaw)
		_box(parent, "Sandbag%d" % i, Vector3(0.5, 0.16, 0.28), world, "Sand", Vector3(0.0, yaw + rng.randf_range(-0.12, 0.12), rng.randf_range(-0.05, 0.05)))


static func span_cable(parent: Node, a: Vector3, b: Vector3, name: String, radius: float = 0.022) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var mesh := CylinderMesh.new()
	var length := a.distance_to(b)
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = maxf(0.05, length)
	mesh.radial_segments = 6
	mesh.rings = 0
	mi.mesh = mesh
	mi.material_override = PbrLibrary.by_kit_name("Rust")
	var mid := (a + b) * 0.5
	var y := b - a
	if y.length_squared() < 1e-6:
		mi.position = mid
		parent.add_child(mi)
		return mi
	var basis := Basis()
	basis.y = y.normalized()
	var helper := Vector3.RIGHT if absf(basis.y.dot(Vector3.UP)) > 0.92 else Vector3.UP
	basis.x = helper.cross(basis.y).normalized()
	basis.z = basis.x.cross(basis.y).normalized()
	mi.transform = Transform3D(basis, mid)
	parent.add_child(mi)
	return mi


static func _turret() -> Node3D:
	var root := Node3D.new()
	root.name = "turret"
	_cyl(root, "Base", 0.78, 0.16, Vector3(0, 0.08, 0), "Concrete", 12)
	_cyl(root, "BaseLip", 0.86, 0.05, Vector3(0, 0.16, 0), "Concrete", 12)
	_cyl(root, "Skirt", 0.82, 0.06, Vector3(0, 0.03, 0), "Tread", 12)
	for i in 6:
		var a := float(i) / 6.0 * TAU
		_cyl(root, "BaseBolt%d" % i, 0.04, 0.05, Vector3(cos(a) * 0.68, 0.18, sin(a) * 0.68), "Oxidized", 6)
	_cyl(root, "Pedestal", 0.22, 0.62, Vector3(0, 0.52, 0), "DarkMetal", 12)
	for i in 4:
		var a := float(i) * PI * 0.5 + 0.2
		_box(root, "PedestalRib%d" % i, Vector3(0.05, 0.52, 0.08), Vector3(cos(a) * 0.22, 0.52, sin(a) * 0.22), "Oxidized", Vector3(0, a, 0))
	_cyl(root, "Collar", 0.28, 0.1, Vector3(0, 0.84, 0), "Oxidized", 12)
	_box(root, "Crate", Vector3(0.38, 0.2, 0.26), Vector3(0.42, 0.22, 0.08), "PaintedMetal")
	_box(root, "CrateTrim", Vector3(0.4, 0.03, 0.28), Vector3(0.42, 0.33, 0.08), "Oxidized")
	_cyl(root, "BaseDust", 1.05, 0.05, Vector3(0, 0.025, 0), "Sand", 10)
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 1.05, 0)
	root.add_child(head)
	_box(head, "Yoke", Vector3(0.72, 0.12, 0.18), Vector3(0, -0.02, 0.02), "DarkMetal")
	_box(head, "YokeArmL", Vector3(0.08, 0.28, 0.16), Vector3(-0.32, 0.08, 0.02), "DarkMetal")
	_box(head, "YokeArmR", Vector3(0.08, 0.28, 0.16), Vector3(0.32, 0.08, 0.02), "DarkMetal")
	_cyl(head, "TrunnionL", 0.045, 0.1, Vector3(-0.38, 0.12, 0.02), "Oxidized", 8, Vector3(0, 0, PI * 0.5))
	_cyl(head, "TrunnionR", 0.045, 0.1, Vector3(0.38, 0.12, 0.02), "Oxidized", 8, Vector3(0, 0, PI * 0.5))
	_box(head, "Housing", Vector3(0.52, 0.28, 0.46), Vector3(0, 0.14, -0.02), "PaintedMetal")
	_box(head, "HousingBevel", Vector3(0.46, 0.06, 0.5), Vector3(0, 0.26, -0.02), "PaintedMetal")
	_box(head, "HousingTrim", Vector3(0.54, 0.03, 0.48), Vector3(0, 0.0, -0.02), "Oxidized")
	_box(head, "Rail", Vector3(0.1, 0.045, 0.38), Vector3(0, 0.3, -0.04), "Metal")
	_cyl_taper(head, "Barrel", 0.048, 0.07, 0.95, Vector3(0, 0.12, -0.62), "Metal", 12, Vector3(-PI * 0.5, 0, 0))
	_cyl(head, "Shroud", 0.09, 0.62, Vector3(0, 0.12, -0.48), "DarkMetal", 12, Vector3(-PI * 0.5, 0, 0))
	_cyl(head, "ShroudRingA", 0.1, 0.04, Vector3(0, 0.12, -0.28), "Oxidized", 10, Vector3(-PI * 0.5, 0, 0))
	_cyl(head, "ShroudRingB", 0.1, 0.04, Vector3(0, 0.12, -0.62), "Oxidized", 10, Vector3(-PI * 0.5, 0, 0))
	_cyl(head, "Brake", 0.055, 0.12, Vector3(0, 0.12, -1.12), "DarkMetal", 10, Vector3(-PI * 0.5, 0, 0))
	_cyl(head, "BrakeSlot", 0.04, 0.08, Vector3(0, 0.12, -1.18), "Metal", 8, Vector3(-PI * 0.5, 0, 0))
	_cyl(head, "Optic", 0.045, 0.12, Vector3(0.0, 0.28, -0.16), "DarkMetal", 10, Vector3(-PI * 0.5, 0, 0))
	_cyl(head, "OpticGlass", 0.032, 0.02, Vector3(0.0, 0.28, -0.22), "Glass", 8, Vector3(-PI * 0.5, 0, 0))
	_box(head, "AmmoDrum", Vector3(0.22, 0.16, 0.22), Vector3(0.28, -0.02, 0.12), "PaintedMetal")
	_box(head, "ArmorCheekL", Vector3(0.08, 0.22, 0.38), Vector3(-0.28, 0.12, -0.04), "Oxidized")
	_box(head, "ArmorCheekR", Vector3(0.08, 0.22, 0.38), Vector3(0.28, 0.12, -0.04), "Oxidized")
	_box(head, "Mantlet", Vector3(0.28, 0.22, 0.08), Vector3(0.0, 0.12, -0.28), "DarkMetal")
	_box(root, "BasePlate", Vector3(1.05, 0.05, 1.05), Vector3(0.0, 0.03, 0.0), "Concrete")
	_box(root, "AccessHatch", Vector3(0.22, 0.04, 0.28), Vector3(-0.42, 0.20, 0.18), "PaintedMetal")
	span_cable(head, Vector3(0.22, -0.08, 0.08), Vector3(0.42, -0.85, 0.08), "PowerCable", 0.014)
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, 0.12, -1.22)
	head.add_child(muzzle)
	compact(root)
	return root


static func _trap() -> Node3D:
	var root := Node3D.new()
	root.name = "trap"
	_box(root, "Pad", Vector3(1.9, 0.1, 1.9), Vector3(0, 0.05, 0), "DarkMetal")
	_box(root, "Grate", Vector3(1.62, 0.04, 1.62), Vector3(0, 0.11, 0), "Tread")
	for i in 9:
		var x := float(i % 3 - 1) * 0.45
		var z := float(i / 3 - 1) * 0.45
		_cone(root, "Spike%d" % i, 0.065, 0.4, Vector3(x, 0.32, z), "Rust")
	for p in [Vector3(0.82, 0.14, 0.82), Vector3(-0.82, 0.14, 0.82), Vector3(0.82, 0.14, -0.82), Vector3(-0.82, 0.14, -0.82)]:
		_box(root, "Warn%s" % str(p), Vector3(0.12, 0.08, 0.12), p, "EmissiveRed")
	compact(root)
	return root


static func _beacon() -> Node3D:
	var root := Node3D.new()
	root.name = "repair_beacon"
	_cyl(root, "Foot", 0.58, 0.14, Vector3(0, 0.07, 0), "Concrete", 14)
	_cyl(root, "Stem", 0.09, 1.2, Vector3(0, 0.72, 0), "Oxidized", 10)
	_cyl(root, "Dish", 0.7, 0.1, Vector3(0, 1.4, 0), "PaintedMetal", 16)
	_sphere(root, "Hub", 0.15, Vector3(0, 1.48, 0), "EmissiveCyan", 10)
	_cyl(root, "Halo", 0.38, 0.05, Vector3(0, 1.6, 0), "EmissiveCyan", 14)
	compact(root)
	return root


static func _ship() -> Node3D:
	var root := Node3D.new()
	root.name = "escape_ship"
	_box(root, "Hull", Vector3(3.35, 0.95, 1.62), Vector3(0, 0.82, 0), "PaintedMetal")
	_box(root, "HullPanel", Vector3(2.4, 0.08, 1.5), Vector3(0.1, 1.28, 0), "Corrugated")
	_box(root, "Nose", Vector3(1.05, 0.62, 1.05), Vector3(1.85, 0.8, 0), "Oxidized")
	_box(root, "Cabin", Vector3(1.05, 0.48, 1.1), Vector3(0.35, 1.42, 0), "Glass")
	_box(root, "Fin", Vector3(0.16, 1.25, 0.62), Vector3(-1.4, 1.5, 0), "DarkMetal")
	_cyl(root, "EngineL", 0.2, 0.5, Vector3(-1.7, 0.68, 0.42), "Metal", 10, Vector3(0, 0, PI * 0.5))
	_cyl(root, "EngineR", 0.2, 0.5, Vector3(-1.7, 0.68, -0.42), "Metal", 10, Vector3(0, 0, PI * 0.5))
	_sphere(root, "GlowL", 0.16, Vector3(-2.0, 0.68, 0.42), "EmissiveAmber", 8)
	_sphere(root, "GlowR", 0.16, Vector3(-2.0, 0.68, -0.42), "EmissiveAmber", 8)
	_box(root, "Strut", Vector3(0.12, 0.14, 1.55), Vector3(0.15, 0.28, 0), "Rust")
	_box(root, "Wear", Vector3(0.8, 0.2, 0.06), Vector3(0.6, 0.55, 0.8), "Rust")
	compact(root)
	return root


static func _tank() -> Node3D:
	var root := Node3D.new()
	root.name = "storage_tank"
	_cyl(root, "Body", 0.82, 2.25, Vector3(0, 1.2, 0), "PaintedMetal", 18)
	_cyl(root, "Band", 0.86, 0.1, Vector3(0, 1.55, 0), "Oxidized", 18)
	_cyl(root, "BandB", 0.86, 0.1, Vector3(0, 0.85, 0), "Oxidized", 18)
	_sphere(root, "Dome", 0.82, Vector3(0, 2.32, 0), "Oxidized", 14)
	_cyl(root, "Pipe", 0.1, 1.25, Vector3(0.92, 0.85, 0), "Rust", 8)
	_box(root, "Valve", Vector3(0.26, 0.18, 0.26), Vector3(0.92, 1.55, 0), "DarkMetal")
	_box(root, "Stripe", Vector3(1.7, 0.16, 0.1), Vector3(0, 1.5, 0), "EmissiveAmber")
	_box(root, "Ladder", Vector3(0.08, 1.6, 0.22), Vector3(0, 1.1, 0.86), "Tread")
	compact(root)
	return root


static func _rifle() -> Node3D:
	# Camera-space DMR: barrel -Z, stock +Z. Beveled receiver, handguard, mag, LPVO.
	var root := Node3D.new()
	root.name = "pulse_rifle"
	_bevel_box(root, "Stock", Vector3(0.032, 0.058, 0.128), Vector3(0.0, 0.012, 0.252), "Polymer", Vector3(0.08, 0, 0), 0.004)
	_cyl_taper(root, "StockTube", 0.014, 0.018, 0.11, Vector3(0.0, 0.02, 0.262), "Polymer", 12, Vector3(-PI * 0.5, 0, 0))
	_box(root, "StockPad", Vector3(0.038, 0.072, 0.02), Vector3(0.0, 0.008, 0.332), "Rubber")
	_cyl(root, "StockPadRound", 0.034, 0.018, Vector3(0.0, 0.008, 0.342), "Rubber", 12, Vector3(-PI * 0.5, 0, 0))
	_box(root, "Cheek", Vector3(0.028, 0.016, 0.07), Vector3(0.0, 0.046, 0.228), "Polymer")
	_cyl(root, "Buffer", 0.015, 0.068, Vector3(0.0, 0.03, 0.168), "DarkMetal", 12, Vector3(-PI * 0.5, 0, 0))
	_bevel_box(root, "Receiver", Vector3(0.042, 0.048, 0.155), Vector3(0.0, 0.03, 0.05), "Metal", Vector3.ZERO, 0.004)
	_cyl(root, "ReceiverRound", 0.02, 0.14, Vector3(0.0, 0.032, 0.048), "Metal", 14, Vector3(-PI * 0.5, 0, 0))
	_bevel_box(root, "Upper", Vector3(0.036, 0.02, 0.148), Vector3(0.0, 0.066, 0.038), "DarkMetal", Vector3.ZERO, 0.003)
	_box(root, "Ejection", Vector3(0.008, 0.016, 0.038), Vector3(0.024, 0.042, 0.048), "DarkMetal")
	_box(root, "ChargingHandle", Vector3(0.03, 0.008, 0.032), Vector3(0.0, 0.08, 0.088), "DarkMetal")
	_box(root, "Rail", Vector3(0.018, 0.007, 0.195), Vector3(0.0, 0.084, -0.012), "DarkMetal")
	for i in 8:
		_box(root, "RailSlot%d" % i, Vector3(0.014, 0.005, 0.007), Vector3(0.0, 0.09, 0.072 - float(i) * 0.024), "DarkMetal")
	_cyl_taper(root, "Grip", 0.013, 0.017, 0.098, Vector3(0.0, -0.06, 0.092), "Polymer", 12, Vector3(0.34, 0, 0))
	_box(root, "GripBevel", Vector3(0.02, 0.055, 0.022), Vector3(0.0, -0.055, 0.09), "Polymer", Vector3(0.34, 0, 0))
	_cyl(root, "TriggerGuard", 0.015, 0.046, Vector3(0.0, -0.028, 0.036), "DarkMetal", 12, Vector3(0.0, 0, PI * 0.5))
	_box(root, "Trigger", Vector3(0.005, 0.018, 0.009), Vector3(0.0, -0.028, 0.026), "DarkMetal")
	_bevel_box(root, "Magwell", Vector3(0.03, 0.026, 0.044), Vector3(0.0, -0.018, 0.0), "DarkMetal", Vector3.ZERO, 0.003)
	_bevel_box(root, "Mag", Vector3(0.026, 0.112, 0.04), Vector3(0.0, -0.098, -0.006), "DarkMetal", Vector3(0.12, 0, 0), 0.003)
	_cyl(root, "MagRound", 0.014, 0.09, Vector3(0.0, -0.098, -0.006), "DarkMetal", 10, Vector3(0.12, 0, 0))
	_box(root, "MagRib", Vector3(0.004, 0.08, 0.03), Vector3(0.014, -0.1, -0.006), "DarkMetal", Vector3(0.12, 0, 0))
	_box(root, "MagBase", Vector3(0.028, 0.012, 0.044), Vector3(0.0, -0.162, 0.006), "Polymer")
	_cyl(root, "Handguard", 0.022, 0.168, Vector3(0.0, 0.028, -0.142), "Polymer", 16, Vector3(-PI * 0.5, 0, 0))
	_cyl(root, "HandguardRing", 0.025, 0.01, Vector3(0.0, 0.028, -0.078), "DarkMetal", 14, Vector3(-PI * 0.5, 0, 0))
	_box(root, "ForeRail", Vector3(0.014, 0.006, 0.125), Vector3(0.0, 0.052, -0.138), "DarkMetal")
	_box(root, "SideRailL", Vector3(0.006, 0.012, 0.1), Vector3(-0.024, 0.028, -0.14), "DarkMetal")
	_box(root, "SideRailR", Vector3(0.006, 0.012, 0.1), Vector3(0.024, 0.028, -0.14), "DarkMetal")
	for i in 5:
		_box(root, "Vent%d" % i, Vector3(0.004, 0.01, 0.012), Vector3(0.023, 0.028, -0.1 - float(i) * 0.018), "DarkMetal")
	_cyl_taper(root, "Barrel", 0.008, 0.013, 0.275, Vector3(0.0, 0.03, -0.375), "Metal", 14, Vector3(-PI * 0.5, 0, 0))
	_cyl(root, "GasBlock", 0.014, 0.026, Vector3(0.0, 0.03, -0.275), "DarkMetal", 10, Vector3(-PI * 0.5, 0, 0))
	_cyl(root, "GasTube", 0.004, 0.12, Vector3(0.0, 0.046, -0.2), "DarkMetal", 8, Vector3(-PI * 0.5, 0, 0))
	_cyl(root, "MuzzleBrake", 0.012, 0.03, Vector3(0.0, 0.03, -0.528), "DarkMetal", 12, Vector3(-PI * 0.5, 0, 0))
	_cyl(root, "BrakeRing", 0.015, 0.008, Vector3(0.0, 0.03, -0.546), "Metal", 10, Vector3(-PI * 0.5, 0, 0))
	_box(root, "OpticMount", Vector3(0.026, 0.014, 0.068), Vector3(0.0, 0.096, 0.018), "DarkMetal")
	_box(root, "OpticRingF", Vector3(0.03, 0.026, 0.014), Vector3(0.0, 0.12, -0.016), "DarkMetal")
	_box(root, "OpticRingR", Vector3(0.03, 0.026, 0.014), Vector3(0.0, 0.12, 0.052), "DarkMetal")
	_cyl(root, "OpticTube", 0.013, 0.108, Vector3(0.0, 0.126, 0.016), "DarkMetal", 16, Vector3(-PI * 0.5, 0, 0))
	_cyl_taper(root, "OpticBell", 0.019, 0.013, 0.03, Vector3(0.0, 0.126, -0.05), "DarkMetal", 16, Vector3(-PI * 0.5, 0, 0))
	_cyl(root, "OpticLens", 0.015, 0.007, Vector3(0.0, 0.126, -0.066), "Glass", 14, Vector3(-PI * 0.5, 0, 0))
	_cyl(root, "OpticEye", 0.014, 0.02, Vector3(0.0, 0.126, 0.078), "DarkMetal", 14, Vector3(-PI * 0.5, 0, 0))
	_cyl(root, "OpticEyeLens", 0.01, 0.005, Vector3(0.0, 0.126, 0.09), "Glass", 12, Vector3(-PI * 0.5, 0, 0))
	_cyl(root, "OpticKnob", 0.01, 0.014, Vector3(0.0, 0.146, 0.018), "DarkMetal", 10)
	_cyl(root, "OpticWindage", 0.008, 0.012, Vector3(0.016, 0.126, 0.018), "DarkMetal", 8, Vector3(0, 0, PI * 0.5))
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0.0, 0.03, -0.56)
	root.add_child(muzzle)
	_box(root, "ReceiverSculpt", Vector3(0.038, 0.042, 0.132), Vector3(0.0, 0.028, 0.046), "Metal")
	_cyl(root, "BarrelStep", 0.011, 0.04, Vector3(0.0, 0.03, -0.255), "DarkMetal", 12, Vector3(-PI * 0.5, 0, 0))
	_cyl(root, "StockHeel", 0.028, 0.022, Vector3(0.0, 0.01, 0.328), "Polymer", 12, Vector3(-PI * 0.5, 0, 0))
	compact(root)
	return root


static func _shotgun() -> Node3D:
	var root := Node3D.new()
	root.name = "scatter_cannon"
	_box(root, "Stock", Vector3(0.05, 0.075, 0.15), Vector3(0, 0.0, 0.2), "Polymer")
	_box(root, "Receiver", Vector3(0.06, 0.08, 0.16), Vector3(0, 0.015, 0.04), "Rust")
	_box(root, "Grip", Vector3(0.04, 0.1, 0.045), Vector3(0, -0.07, 0.07), "Polymer")
	_cyl(root, "Barrel", 0.018, 0.22, Vector3(0.012, 0.025, -0.18), "Metal", 10, Vector3(-PI * 0.5, 0, 0))
	_cyl(root, "BarrelB", 0.018, 0.22, Vector3(-0.012, 0.025, -0.18), "Metal", 10, Vector3(-PI * 0.5, 0, 0))
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, 0.025, -0.3)
	root.add_child(muzzle)
	return root


static func _rock(seed: int, scale: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "rock"
	var mi := MeshInstance3D.new()
	mi.name = "Rock"
	mi.mesh = boulder_mesh(seed, scale, 16, 11)
	mi.material_override = PbrLibrary.boulder()
	root.add_child(mi)
	return root


static func boulder_mesh(seed: int, scale: Vector3, segs: int = 16, rings: int = 11) -> ArrayMesh:
	var key := "%d_%.3f_%.3f_%.3f_%d_%d" % [seed, scale.x, scale.y, scale.z, segs, rings]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[Vector3] = []
	# Bedded sandstone slab: flatten the sphere, cut a few fracture planes, terrace strata.
	var n_a := Vector3(_n3(Vector3(0.2, 0.7, -0.1), seed) - 0.5, 0.18, _n3(Vector3(-0.4, 0.2, 0.6), seed + 1) - 0.5).normalized()
	var n_b := Vector3(_n3(Vector3(0.8, 0.1, 0.2), seed + 2) - 0.5, 0.08, _n3(Vector3(0.1, 0.4, -0.7), seed + 4) - 0.5).normalized()
	var n_c := Vector3(0.15, 0.96, 0.12).normalized()
	var cut_a := 0.22 + 0.12 * _n3(Vector3(1, 0, 0), seed)
	var cut_b := 0.28 + 0.10 * _n3(Vector3(0, 1, 0), seed + 5)
	for r in range(rings + 1):
		var v := float(r) / float(rings)
		var phi := v * PI
		for s in segs:
			var u := float(s) / float(segs)
			var th := u * TAU
			var dir := Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th))
			var n1 := _n3(dir, seed)
			var n2 := _n3(dir * 2.15 + Vector3(0.17, 0.05, -0.11), seed + 3)
			var n3 := _n3(dir * 4.4 + Vector3(-0.3, 0.2, 0.14), seed + 9)
			var disp := 0.08 * n1 + 0.04 * n2 + 0.018 * n3
			disp -= clampf(dir.y, 0.0, 1.0) * 0.10 * n1
			var p := Vector3(dir.x * scale.x, dir.y * scale.y * 0.72, dir.z * scale.z)
			p *= 1.0 + disp
			# Horizontal beds / terraces.
			var bed := sin(p.y * (11.0 / maxf(0.08, scale.y)) + n1 * 0.7)
			p.y += bed * 0.028 * scale.y
			p.x *= 1.0 + 0.08 * bed * (1.0 - absf(dir.y))
			p.z *= 1.0 + 0.06 * bed * (1.0 - absf(dir.y))
			# Fracture planes: flatten one face, chip another.
			var da := p.dot(n_a) - cut_a * scale.x
			if da > 0.0:
				p -= n_a * da * 0.92
			var db := p.dot(n_b) - cut_b * scale.z
			if db > 0.0:
				p -= n_b * db * 0.78
			var dc := p.dot(n_c) - scale.y * 0.55
			if dc > 0.0:
				p -= n_c * dc * 0.85
			pts.append(p)
	var min_y := 999.0
	for p in pts:
		min_y = minf(min_y, p.y)
	for i in pts.size():
		pts[i].y -= min_y
		if pts[i].y < scale.y * 0.018:
			pts[i].y = scale.y * 0.018
			pts[i].x *= 1.08
			pts[i].z *= 1.08
	for r in rings:
		for s in segs:
			var i0 := r * segs + s
			var i1 := r * segs + ((s + 1) % segs)
			var i2 := (r + 1) * segs + s
			var i3 := (r + 1) * segs + ((s + 1) % segs)
			_tri(st, pts[i0], pts[i2], pts[i1])
			_tri(st, pts[i1], pts[i2], pts[i3])
	st.generate_normals()
	var mesh := st.commit()
	_mesh_cache[key] = mesh
	return mesh


static func compact(root: Node3D) -> void:
	if root == null:
		return
	_compact_into(root, ["Head", "Heart", "Muzzle"])
	var head := root.find_child("Head", false, false)
	if head is Node3D:
		_compact_into(head as Node3D, ["Muzzle"])


static func _compact_into(root: Node3D, skip_names: PackedStringArray) -> void:
	var groups: Dictionary = {}
	var hide: Array[MeshInstance3D] = []
	_gather_meshes(root, root, skip_names, groups, hide, true)
	var gi := 0
	for mat in groups:
		var st: SurfaceTool = groups[mat]
		var baked := MeshInstance3D.new()
		baked.name = "Lod0_%d" % gi
		gi += 1
		baked.mesh = st.commit()
		baked.material_override = mat
		baked.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		root.add_child(baked)
	for mi in hide:
		mi.visible = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _gather_meshes(root: Node3D, node: Node, skip_names: PackedStringArray, groups: Dictionary, hide: Array[MeshInstance3D], is_root: bool) -> void:
	if not is_root:
		for skip in skip_names:
			if node.name == skip:
				return
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.visible and mi.mesh != null and mi.mesh.get_surface_count() > 0:
			var mat: Material = mi.material_override
			if mat == null:
				mat = mi.get_active_material(0)
			if mat == null:
				mat = StandardMaterial3D.new()
			if not groups.has(mat):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[mat] = st
			(groups[mat] as SurfaceTool).append_from(mi.mesh, 0, _xform_to(root, mi))
			hide.append(mi)
	for child in node.get_children():
		_gather_meshes(root, child, skip_names, groups, hide, false)


static func _xform_to(root: Node, node: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var walk: Node = node
	while walk != null and walk != root:
		if walk is Node3D:
			xf = (walk as Node3D).transform * xf
		walk = walk.get_parent()
	return xf


static func _n3(p: Vector3, seed: int) -> float:
	var x := p.x * 3.1 + float(seed) * 0.017
	var y := p.y * 3.1 + 19.0
	var z := p.z * 3.1 - 7.0
	var ix := int(floor(x))
	var iy := int(floor(y))
	var iz := int(floor(z))
	var fx := x - float(ix)
	var fy := y - float(iy)
	var fz := z - float(iz)
	var ux := fx * fx * (3.0 - 2.0 * fx)
	var uy := fy * fy * (3.0 - 2.0 * fy)
	var uz := fz * fz * (3.0 - 2.0 * fz)
	var n000 := _h3(ix, iy, iz)
	var n100 := _h3(ix + 1, iy, iz)
	var n010 := _h3(ix, iy + 1, iz)
	var n110 := _h3(ix + 1, iy + 1, iz)
	var n001 := _h3(ix, iy, iz + 1)
	var n101 := _h3(ix + 1, iy, iz + 1)
	var n011 := _h3(ix, iy + 1, iz + 1)
	var n111 := _h3(ix + 1, iy + 1, iz + 1)
	var x00 := lerpf(n000, n100, ux)
	var x10 := lerpf(n010, n110, ux)
	var x01 := lerpf(n001, n101, ux)
	var x11 := lerpf(n011, n111, ux)
	return lerpf(lerpf(x00, x10, uy), lerpf(x01, x11, uy), uz)


static func _h3(ix: int, iy: int, iz: int) -> float:
	var n: int = ix * 374761393 + iy * 668265263 + iz * 1274126177
	n = (n ^ (n >> 13)) * 1274126177
	return float(n & 0x7fffffff) / 2147483647.0


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-10:
		n = Vector3.UP
	else:
		n = n.normalized()
	st.set_normal(n)
	st.set_uv(Vector2(a.x, a.z) * 0.45)
	st.add_vertex(a)
	st.set_normal(n)
	st.set_uv(Vector2(b.x, b.z) * 0.45)
	st.add_vertex(b)
	st.set_normal(n)
	st.set_uv(Vector2(c.x, c.z) * 0.45)
	st.add_vertex(c)


static func _box(parent: Node, name: String, size: Vector3, pos: Vector3, mat: String, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.material_override = PbrLibrary.by_kit_name(mat)
	parent.add_child(mi)
	return mi


static func _bevel_box(parent: Node, name: String, size: Vector3, pos: Vector3, mat: String, rot: Vector3 = Vector3.ZERO, bevel: float = 0.01) -> MeshInstance3D:
	var b := minf(bevel, minf(size.x, minf(size.y, size.z)) * 0.35)
	var main := _box(parent, name, Vector3(size.x - 2.0 * b, size.y, size.z - 2.0 * b), pos, mat, rot)
	_box(parent, name + "BevelY", Vector3(size.x, size.y - 2.0 * b, size.z - 2.0 * b), pos, mat, rot)
	_box(parent, name + "BevelZ", Vector3(size.x - 2.0 * b, size.y - 2.0 * b, size.z), pos, mat, rot)
	return main


static func _cyl(parent: Node, name: String, radius: float, height: float, pos: Vector3, mat: String, segs: int = 12, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return _cyl_taper(parent, name, radius, radius, height, pos, mat, segs, rot)


static func _cyl_taper(parent: Node, name: String, r_top: float, r_bot: float, height: float, pos: Vector3, mat: String, segs: int = 12, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var mesh := CylinderMesh.new()
	mesh.top_radius = r_top
	mesh.bottom_radius = r_bot
	mesh.height = height
	mesh.radial_segments = segs
	mesh.rings = 0
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.material_override = PbrLibrary.by_kit_name(mat)
	parent.add_child(mi)
	return mi


static func _sphere(parent: Node, name: String, radius: float, pos: Vector3, mat: String, segs: int = 12) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segs
	mesh.rings = maxi(6, segs / 2)
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = PbrLibrary.by_kit_name(mat)
	parent.add_child(mi)
	return mi


static func _cone(parent: Node, name: String, radius: float, height: float, pos: Vector3, mat: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = PbrLibrary.by_kit_name(mat)
	parent.add_child(mi)
	return mi
