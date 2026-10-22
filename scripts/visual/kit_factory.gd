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
			return build_wall_variant(variant)
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


static func build_wall_variant(variant: int) -> Node3D:
	var v: int = variant % 4
	return _proto_dup("wall_%d" % v, _make_wall.bind(v))


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


static func cover_butte_mesh(kind: int) -> ArrayMesh:
	var i: int = clampi(kind, 0, 2)
	var baked := load_baked_mesh("butte_%d" % i)
	if baked:
		return baked
	var seeds: Array[int] = [4, 21, 37]
	var scales: Array[Vector3] = [
		Vector3(1.0, 1.0, 1.0),
		Vector3(1.0, 1.0, 0.78),
		Vector3(0.84, 1.0, 1.18),
	]
	return butte_mesh(seeds[i], scales[i], 24, 14)


static func generate_cover_boulder_mesh(kind: int) -> ArrayMesh:
	var i: int = clampi(kind, 0, 2)
	var seeds: Array[int] = [11, 27, 43]
	var scales: Array[Vector3] = [
		Vector3(1.15, 0.38, 0.82),
		Vector3(1.35, 0.32, 0.95),
		Vector3(0.92, 0.36, 1.18),
	]
	return boulder_mesh(seeds[i], scales[i], 14, 9)


static func generate_cover_butte_mesh(kind: int) -> ArrayMesh:
	var i: int = clampi(kind, 0, 2)
	var seeds: Array[int] = [4, 21, 37]
	var scales: Array[Vector3] = [
		Vector3(1.0, 1.0, 1.0),
		Vector3(1.0, 1.0, 0.78),
		Vector3(0.84, 1.0, 1.18),
	]
	return butte_mesh(seeds[i], scales[i], 24, 14)


static func generate_pebble_mesh() -> ArrayMesh:
	return boulder_mesh(91, Vector3(1.0, 0.42, 1.0), 8, 6)


static func clear_mesh_cache() -> void:
	_mesh_cache.clear()


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
	# Modular fortification for a 2 m cell: HESCO, T-wall, or welded plate.
	# No shed roofs or antennas — those read as crates from the title camera.
	var root := Node3D.new()
	root.name = "wall"
	_box(root, "Plinth", Vector3(2.16, 0.16, 1.22), Vector3(0.0, 0.06, 0.04), "Concrete")
	_box(root, "PlinthBevel", Vector3(2.00, 0.07, 1.06), Vector3(0.0, 0.14, 0.03), "Concrete")
	_box(root, "PlinthLip", Vector3(2.22, 0.04, 1.28), Vector3(0.0, 0.16, 0.04), "Tread")
	_cyl(root, "BaseDust", 1.28, 0.07, Vector3(0.0, 0.024, 0.10), "Sand", 10)
	match variant:
		1:
			_twall_body(root)
		3:
			_steel_wall_body(root)
		2:
			_hesco_wall_body(root, 1.08, false)
		_:
			_hesco_wall_body(root, 1.68, true)
	for i in 6:
		var x := -0.85 + float(i) * 0.34
		_cyl(root, "Bolt%d" % i, 0.022, 0.036, Vector3(x, 0.19, 0.62), "Oxidized", 6)
	_box(root, "PanelSeam0", Vector3(0.028, 1.12, 0.04), Vector3(0.0, 0.82, 0.58), "DarkMetal")
	_box(root, "Wear0", Vector3(0.62, 0.24, 0.05), Vector3(0.48, 0.30, 0.60), "Rust")
	_box(root, "CornerPost0", Vector3(0.09, 1.48, 0.09), Vector3(-1.04, 0.84, 0.50), "Oxidized")
	_box(root, "CornerPost1", Vector3(0.09, 1.48, 0.09), Vector3(1.04, 0.84, 0.50), "Oxidized")
	_box(root, "Buttress0", Vector3(0.12, 0.92, 0.58), Vector3(0.0, 0.58, -0.52), "Oxidized", Vector3(0.48, 0.0, 0.0))
	_box(root, "Brace0", Vector3(0.07, 0.08, 0.78), Vector3(-0.78, 0.44, -0.18), "Oxidized", Vector3(0.42, 0.0, 0.0))
	_box(root, "Gusset0", Vector3(0.16, 0.08, 0.28), Vector3(-0.92, 0.28, 0.42), "Oxidized")
	_box(root, "Weld0", Vector3(0.03, 1.05, 0.03), Vector3(1.04, 0.78, 0.54), "Rust")
	sandbag_stack(root, Vector3(0.0, 0.16, 0.72), 0.0, 4 if variant == 2 else 3, 21 + variant)
	compact(root)
	return root


static func _hesco_wall_body(root: Node3D, height: float, two_course: bool) -> void:
	var course_h := height * 0.5 if two_course else height
	_hesco_cell(root, "HescoL", Vector3(0.98, course_h, 0.98), Vector3(-0.52, 0.16, 0.02), 0.0, true)
	_hesco_cell(root, "HescoR", Vector3(0.98, course_h, 0.96), Vector3(0.52, 0.16, 0.0), 0.02, false)
	if two_course:
		_hesco_cell(root, "HescoLT", Vector3(0.95, course_h * 0.96, 0.95), Vector3(-0.50, 0.16 + course_h, 0.01), 0.03, false)
		_hesco_cell(root, "HescoRT", Vector3(0.95, course_h * 0.94, 0.95), Vector3(0.50, 0.16 + course_h, -0.01), -0.02, false)


static func _hesco_cell(parent: Node, stem: String, size: Vector3, pos: Vector3, yaw: float, primary: bool) -> void:
	var fill_name := "HescoFill0" if primary else "%sFill" % stem
	_box(parent, fill_name, Vector3(size.x * 0.97, size.y * 0.96, size.z * 0.97), pos + Vector3(0.0, size.y * 0.5, 0.0), "Sand", Vector3(0.0, yaw, 0.0))
	var hx := size.x * 0.495
	var hz := size.z * 0.495
	var corners: Array[Vector3] = [
		Vector3(-hx, 0.0, -hz), Vector3(hx, 0.0, -hz), Vector3(-hx, 0.0, hz), Vector3(hx, 0.0, hz),
	]
	for i in 4:
		var p := pos + corners[i].rotated(Vector3.UP, yaw) + Vector3(0.0, size.y * 0.5, 0.0)
		_cyl(parent, "%sPost%d" % [stem, i], 0.022, size.y, p, "DarkMetal", 6)
	for b in 3:
		var by := pos.y + size.y * (0.16 + float(b) * 0.34)
		var band_name := "CageBand0" if primary and b == 0 else "%sBand%d" % [stem, b]
		_box(parent, band_name, Vector3(size.x + 0.03, 0.018, 0.018), Vector3(pos.x, by, pos.z + size.z * 0.5), "DarkMetal", Vector3(0.0, yaw, 0.0))
		_box(parent, "%sBandB%d" % [stem, b], Vector3(size.x + 0.03, 0.018, 0.018), Vector3(pos.x, by, pos.z - size.z * 0.5), "DarkMetal", Vector3(0.0, yaw, 0.0))
		_box(parent, "%sBandS%d" % [stem, b], Vector3(0.018, 0.018, size.z + 0.03), Vector3(pos.x + size.x * 0.5, by, pos.z), "DarkMetal", Vector3(0.0, yaw, 0.0))
		_box(parent, "%sBandT%d" % [stem, b], Vector3(0.018, 0.018, size.z + 0.03), Vector3(pos.x - size.x * 0.5, by, pos.z), "DarkMetal", Vector3(0.0, yaw, 0.0))
	for w in 3:
		var wx := pos.x + (-0.32 + float(w) * 0.32)
		_box(parent, "%sWireF%d" % [stem, w], Vector3(0.014, size.y * 0.92, 0.014), Vector3(wx, pos.y + size.y * 0.5, pos.z + size.z * 0.5), "DarkMetal", Vector3(0.0, yaw, 0.0))
		_box(parent, "%sWireB%d" % [stem, w], Vector3(0.014, size.y * 0.92, 0.014), Vector3(wx, pos.y + size.y * 0.5, pos.z - size.z * 0.5), "DarkMetal", Vector3(0.0, yaw, 0.0))
	_box(parent, "%sLip" % stem, Vector3(size.x + 0.04, 0.03, size.z + 0.04), pos + Vector3(0.0, size.y, 0.0), "Oxidized", Vector3(0.0, yaw, 0.0))


static func _twall_body(root: Node3D) -> void:
	_box(root, "TWallFoot", Vector3(2.18, 0.30, 1.14), Vector3(0.0, 0.24, 0.0), "Concrete")
	_box(root, "TWallFootBevel", Vector3(1.78, 0.14, 0.70), Vector3(0.0, 0.42, 0.0), "Concrete")
	_box(root, "TWallStem", Vector3(2.02, 1.38, 0.30), Vector3(0.0, 1.12, 0.0), "Concrete")
	_box(root, "TWallCap", Vector3(2.10, 0.10, 0.38), Vector3(0.0, 1.86, 0.0), "Concrete")
	_box(root, "SteelPlate0", Vector3(1.88, 1.12, 0.05), Vector3(0.0, 1.08, 0.18), "PaintedMetal")
	for i in 3:
		_box(root, "Seam%d" % i, Vector3(0.024, 1.18, 0.04), Vector3(-0.62 + float(i) * 0.62, 1.08, 0.20), "DarkMetal")
	for i in 8:
		_cyl(root, "FaceBolt%d" % i, 0.016, 0.028, Vector3(-0.72 + float(i % 4) * 0.48, 0.72 + float(i / 4) * 0.68, 0.22), "Oxidized", 6)


static func _steel_wall_body(root: Node3D) -> void:
	_box(root, "SteelPlate0", Vector3(2.06, 1.52, 0.08), Vector3(0.0, 0.96, 0.12), "Oxidized")
	_box(root, "SteelPlate1", Vector3(1.02, 1.44, 0.06), Vector3(-0.50, 0.94, 0.18), "PaintedMetal")
	_box(root, "SteelPlate2", Vector3(1.02, 1.38, 0.06), Vector3(0.52, 0.92, 0.18), "PaintedMetal")
	_box(root, "Weld1", Vector3(0.04, 1.36, 0.04), Vector3(0.0, 0.94, 0.22), "Rust")
	_box(root, "IBeamL", Vector3(0.12, 1.58, 0.14), Vector3(-0.98, 0.96, -0.10), "DarkMetal")
	_box(root, "IBeamR", Vector3(0.12, 1.58, 0.14), Vector3(0.98, 0.96, -0.10), "DarkMetal")
	for i in 4:
		_box(root, "Flange%d" % i, Vector3(0.22, 0.04, 0.22), Vector3(-0.98 if i < 2 else 0.98, 0.28 + float(i % 2) * 1.38, -0.10), "Oxidized")
	for r in 3:
		for c in 4:
			_cyl(root, "PlateBolt%d_%d" % [r, c], 0.014, 0.024, Vector3(-0.72 + float(c) * 0.48, 0.55 + float(r) * 0.42, 0.22), "Oxidized", 6)


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
	_box(root, "BasePlate", Vector3(1.32, 0.07, 1.32), Vector3(0.0, 0.035, 0.0), "Concrete")
	_cyl(root, "BaseRing", 0.64, 0.14, Vector3(0.0, 0.12, 0.0), "Oxidized", 20)
	_cyl(root, "BaseRingLip", 0.70, 0.045, Vector3(0.0, 0.20, 0.0), "DarkMetal", 20)
	_cyl(root, "Skirt", 0.74, 0.05, Vector3(0.0, 0.04, 0.0), "Tread", 16)
	for i in 8:
		var a := float(i) / 8.0 * TAU
		_cyl(root, "BaseBolt%d" % i, 0.03, 0.05, Vector3(cos(a) * 0.58, 0.22, sin(a) * 0.58), "Oxidized", 6)
		_box(root, "RingTooth%d" % i, Vector3(0.055, 0.045, 0.09), Vector3(cos(a) * 0.66, 0.16, sin(a) * 0.66), "DarkMetal", Vector3(0.0, a, 0.0))
	_cyl(root, "Pedestal", 0.26, 0.38, Vector3(0.0, 0.40, 0.0), "DarkMetal", 14)
	for i in 4:
		var a := float(i) * PI * 0.5 + 0.32
		_box(root, "PedestalRib%d" % i, Vector3(0.06, 0.34, 0.16), Vector3(cos(a) * 0.24, 0.40, sin(a) * 0.24), "Oxidized", Vector3(0.0, a, 0.0))
	_cyl(root, "YawBearing", 0.32, 0.10, Vector3(0.0, 0.62, 0.0), "GunSteel", 16)
	_box(root, "AccessHatch", Vector3(0.28, 0.04, 0.32), Vector3(-0.44, 0.18, 0.24), "PaintedMetal")
	_box(root, "AmmoCrate", Vector3(0.30, 0.20, 0.24), Vector3(0.50, 0.22, 0.16), "PaintedMetal")
	_box(root, "AmmoCrateTrim", Vector3(0.32, 0.03, 0.26), Vector3(0.50, 0.33, 0.16), "Oxidized")
	_cyl(root, "BaseDust", 1.08, 0.055, Vector3(0.0, 0.028, 0.0), "Sand", 10)
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.0, 0.88, 0.0)
	root.add_child(head)
	_cyl(head, "YawHousing", 0.36, 0.26, Vector3(0.0, 0.04, 0.04), "PaintedMetal", 16)
	_cyl(head, "YawHousingCap", 0.32, 0.06, Vector3(0.0, 0.18, 0.04), "Oxidized", 16)
	_box(head, "Yoke", Vector3(0.82, 0.13, 0.20), Vector3(0.0, 0.10, 0.02), "DarkMetal")
	_box(head, "YokeArmL", Vector3(0.09, 0.34, 0.18), Vector3(-0.38, 0.22, 0.02), "DarkMetal")
	_box(head, "YokeArmR", Vector3(0.09, 0.34, 0.18), Vector3(0.38, 0.22, 0.02), "DarkMetal")
	_cyl(head, "TrunnionL", 0.05, 0.12, Vector3(-0.44, 0.24, 0.02), "Oxidized", 10, Vector3(0.0, 0.0, PI * 0.5))
	_cyl(head, "TrunnionR", 0.05, 0.12, Vector3(0.44, 0.24, 0.02), "Oxidized", 10, Vector3(0.0, 0.0, PI * 0.5))
	_cyl(head, "PitchHousing", 0.20, 0.48, Vector3(0.0, 0.24, -0.02), "PaintedMetal", 14, Vector3(-PI * 0.5, 0.0, 0.0))
	_cyl(head, "PitchHousingRear", 0.22, 0.16, Vector3(0.0, 0.24, 0.18), "Oxidized", 14, Vector3(-PI * 0.5, 0.0, 0.0))
	_box(head, "HousingBevel", Vector3(0.28, 0.08, 0.36), Vector3(0.0, 0.40, -0.02), "PaintedMetal")
	_box(head, "Mantlet", Vector3(0.30, 0.24, 0.10), Vector3(0.0, 0.22, -0.32), "DarkMetal")
	_cyl(head, "MantletRing", 0.11, 0.07, Vector3(0.0, 0.22, -0.36), "Oxidized", 12, Vector3(-PI * 0.5, 0.0, 0.0))
	_box(head, "ArmorCheekL", Vector3(0.07, 0.24, 0.40), Vector3(-0.24, 0.22, -0.06), "Oxidized")
	_box(head, "ArmorCheekR", Vector3(0.07, 0.24, 0.40), Vector3(0.24, 0.22, -0.06), "Oxidized")
	_cyl(head, "Shroud", 0.082, 0.78, Vector3(0.0, 0.22, -0.68), "DarkMetal", 14, Vector3(-PI * 0.5, 0.0, 0.0))
	_cyl_taper(head, "Barrel", 0.034, 0.052, 1.12, Vector3(0.0, 0.22, -0.82), "GunSteel", 14, Vector3(-PI * 0.5, 0.0, 0.0))
	for i in 4:
		_cyl(head, "ShroudPort%d" % i, 0.09, 0.028, Vector3(0.0, 0.22, -0.44 - float(i) * 0.13), "Oxidized", 10, Vector3(-PI * 0.5, 0.0, 0.0))
	_cyl(head, "MuzzleBrake", 0.046, 0.15, Vector3(0.0, 0.22, -1.38), "DarkMetal", 12, Vector3(-PI * 0.5, 0.0, 0.0))
	_cyl(head, "Brake", 0.038, 0.07, Vector3(0.0, 0.22, -1.48), "GunSteel", 10, Vector3(-PI * 0.5, 0.0, 0.0))
	_cyl(head, "Optic", 0.038, 0.16, Vector3(0.0, 0.40, -0.10), "DarkMetal", 10, Vector3(-PI * 0.5, 0.0, 0.0))
	_cyl(head, "OpticGlass", 0.026, 0.02, Vector3(0.0, 0.40, -0.18), "Glass", 8, Vector3(-PI * 0.5, 0.0, 0.0))
	_box(head, "AmmoDrum", Vector3(0.18, 0.16, 0.18), Vector3(0.28, 0.06, 0.16), "PaintedMetal")
	_box(head, "Stencil0", Vector3(0.16, 0.07, 0.012), Vector3(0.20, 0.30, 0.22), "PaintedMetal")
	_box(head, "Hydraulics", Vector3(0.045, 0.045, 0.30), Vector3(0.16, 0.08, -0.16), "Oxidized", Vector3(0.32, 0.0, 0.0))
	span_cable(head, Vector3(0.22, -0.08, 0.10), Vector3(0.50, -0.72, 0.16), "PowerCable", 0.016)
	span_cable(head, Vector3(-0.18, -0.05, 0.08), Vector3(-0.38, -0.68, 0.12), "DataCable", 0.012)
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0.0, 0.22, -1.56)
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
	# Camera-space DMR (SR-25/M110 layout): barrel -Z, stock +Z.
	# Cylinders carry the silhouette so it does not read as stacked boxes.
	var root := Node3D.new()
	root.name = "pulse_rifle"
	_cyl_taper(root, "Stock", 0.016, 0.022, 0.118, Vector3(0.0, 0.018, 0.255), "GunPolymer", 14, Vector3(-PI * 0.5 + 0.08, 0.0, 0.0))
	_cyl(root, "StockTube", 0.013, 0.09, Vector3(0.0, 0.024, 0.205), "GunDark", 12, Vector3(-PI * 0.5, 0.0, 0.0))
	_cyl(root, "StockPad", 0.024, 0.018, Vector3(0.0, 0.010, 0.328), "Rubber", 14, Vector3(-PI * 0.5, 0.0, 0.0))
	_cyl(root, "StockPadRound", 0.026, 0.012, Vector3(0.0, 0.010, 0.340), "Rubber", 14, Vector3(-PI * 0.5, 0.0, 0.0))
	_cyl(root, "StockHeel", 0.022, 0.02, Vector3(0.0, 0.008, 0.318), "GunPolymer", 12, Vector3(-PI * 0.5, 0.0, 0.0))
	_box(root, "Cheek", Vector3(0.026, 0.014, 0.062), Vector3(0.0, 0.044, 0.232), "GunPolymer")
	_cyl(root, "Buffer", 0.014, 0.055, Vector3(0.0, 0.028, 0.155), "GunDark", 12, Vector3(-PI * 0.5, 0.0, 0.0))
	_cyl(root, "ReceiverRound", 0.021, 0.132, Vector3(0.0, 0.030, 0.042), "GunSteel", 16, Vector3(-PI * 0.5, 0.0, 0.0))
	_bevel_box(root, "Receiver", Vector3(0.036, 0.038, 0.128), Vector3(0.0, 0.028, 0.042), "GunSteel", Vector3.ZERO, 0.005)
	_cyl(root, "UpperTube", 0.018, 0.122, Vector3(0.0, 0.048, 0.030), "GunDark", 14, Vector3(-PI * 0.5, 0.0, 0.0))
	_box(root, "Upper", Vector3(0.032, 0.016, 0.120), Vector3(0.0, 0.058, 0.028), "GunDark")
	_box(root, "Ejection", Vector3(0.006, 0.014, 0.034), Vector3(0.020, 0.040, 0.040), "GunDark")
	_box(root, "ChargingHandle", Vector3(0.028, 0.006, 0.028), Vector3(0.0, 0.072, 0.082), "GunDark")
	_box(root, "Rail", Vector3(0.016, 0.006, 0.210), Vector3(0.0, 0.078, -0.018), "GunDark")
	for i in 9:
		_box(root, "RailSlot%d" % i, Vector3(0.012, 0.004, 0.006), Vector3(0.0, 0.084, 0.078 - float(i) * 0.022), "GunDark")
	_cyl_taper(root, "Grip", 0.012, 0.016, 0.092, Vector3(0.0, -0.058, 0.088), "GunPolymer", 12, Vector3(0.38, 0.0, 0.0))
	_box(root, "GripBevel", Vector3(0.018, 0.048, 0.020), Vector3(0.0, -0.052, 0.086), "GunPolymer", Vector3(0.38, 0.0, 0.0))
	_cyl(root, "TriggerGuard", 0.014, 0.042, Vector3(0.0, -0.026, 0.032), "GunDark", 12, Vector3(0.0, 0.0, PI * 0.5))
	_box(root, "Trigger", Vector3(0.004, 0.016, 0.008), Vector3(0.0, -0.026, 0.022), "GunDark")
	_bevel_box(root, "Magwell", Vector3(0.028, 0.022, 0.040), Vector3(0.0, -0.016, -0.002), "GunDark", Vector3.ZERO, 0.003)
	_cyl_taper(root, "Mag", 0.011, 0.014, 0.102, Vector3(0.0, -0.092, -0.004), "GunDark", 12, Vector3(0.14, 0.0, 0.0))
	_box(root, "MagBody", Vector3(0.022, 0.092, 0.034), Vector3(0.0, -0.092, -0.004), "GunDark", Vector3(0.14, 0.0, 0.0))
	_cyl(root, "MagRound", 0.012, 0.078, Vector3(0.0, -0.090, -0.004), "GunDark", 10, Vector3(0.14, 0.0, 0.0))
	_box(root, "MagRib", Vector3(0.003, 0.07, 0.026), Vector3(0.012, -0.092, -0.004), "GunDark", Vector3(0.14, 0.0, 0.0))
	_box(root, "MagBase", Vector3(0.026, 0.010, 0.038), Vector3(0.0, -0.150, 0.008), "GunPolymer")
	_cyl(root, "Handguard", 0.020, 0.175, Vector3(0.0, 0.028, -0.148), "GunPolymer", 16, Vector3(-PI * 0.5, 0.0, 0.0))
	_cyl(root, "HandguardRing", 0.023, 0.01, Vector3(0.0, 0.028, -0.072), "GunDark", 14, Vector3(-PI * 0.5, 0.0, 0.0))
	_cyl(root, "HandguardCap", 0.021, 0.012, Vector3(0.0, 0.028, -0.232), "GunDark", 14, Vector3(-PI * 0.5, 0.0, 0.0))
	_box(root, "ForeRail", Vector3(0.012, 0.005, 0.132), Vector3(0.0, 0.050, -0.148), "GunDark")
	_box(root, "SideRailL", Vector3(0.005, 0.010, 0.108), Vector3(-0.022, 0.028, -0.148), "GunDark")
	_box(root, "SideRailR", Vector3(0.005, 0.010, 0.108), Vector3(0.022, 0.028, -0.148), "GunDark")
	for i in 6:
		_box(root, "Vent%d" % i, Vector3(0.003, 0.008, 0.010), Vector3(0.021, 0.028, -0.092 - float(i) * 0.018), "GunDark")
	_cyl_taper(root, "Barrel", 0.007, 0.012, 0.292, Vector3(0.0, 0.028, -0.388), "GunSteel", 14, Vector3(-PI * 0.5, 0.0, 0.0))
	_cyl(root, "BarrelStep", 0.010, 0.036, Vector3(0.0, 0.028, -0.262), "GunDark", 12, Vector3(-PI * 0.5, 0.0, 0.0))
	_cyl(root, "GasBlock", 0.013, 0.024, Vector3(0.0, 0.028, -0.278), "GunDark", 10, Vector3(-PI * 0.5, 0.0, 0.0))
	_cyl(root, "GasTube", 0.0035, 0.115, Vector3(0.0, 0.044, -0.205), "GunDark", 8, Vector3(-PI * 0.5, 0.0, 0.0))
	_cyl(root, "MuzzleBrake", 0.011, 0.032, Vector3(0.0, 0.028, -0.542), "GunDark", 12, Vector3(-PI * 0.5, 0.0, 0.0))
	_cyl(root, "BrakeRing", 0.014, 0.007, Vector3(0.0, 0.028, -0.560), "GunSteel", 10, Vector3(-PI * 0.5, 0.0, 0.0))
	_box(root, "OpticMount", Vector3(0.024, 0.012, 0.062), Vector3(0.0, 0.090, 0.014), "GunDark")
	_cyl(root, "OpticRingF", 0.016, 0.014, Vector3(0.0, 0.118, -0.018), "GunDark", 12, Vector3(-PI * 0.5, 0.0, 0.0))
	_cyl(root, "OpticRingR", 0.016, 0.014, Vector3(0.0, 0.118, 0.052), "GunDark", 12, Vector3(-PI * 0.5, 0.0, 0.0))
	_cyl(root, "OpticTube", 0.012, 0.112, Vector3(0.0, 0.122, 0.016), "GunDark", 16, Vector3(-PI * 0.5, 0.0, 0.0))
	_cyl_taper(root, "OpticBell", 0.018, 0.012, 0.028, Vector3(0.0, 0.122, -0.052), "GunDark", 16, Vector3(-PI * 0.5, 0.0, 0.0))
	_cyl(root, "OpticLens", 0.014, 0.006, Vector3(0.0, 0.122, -0.068), "Glass", 14, Vector3(-PI * 0.5, 0.0, 0.0))
	_cyl(root, "OpticEye", 0.013, 0.018, Vector3(0.0, 0.122, 0.078), "GunDark", 14, Vector3(-PI * 0.5, 0.0, 0.0))
	_cyl(root, "OpticEyeLens", 0.009, 0.004, Vector3(0.0, 0.122, 0.090), "Glass", 12, Vector3(-PI * 0.5, 0.0, 0.0))
	_cyl(root, "OpticKnob", 0.009, 0.012, Vector3(0.0, 0.142, 0.016), "GunDark", 10)
	_cyl(root, "OpticWindage", 0.007, 0.011, Vector3(0.015, 0.122, 0.016), "GunDark", 8, Vector3(0.0, 0.0, PI * 0.5))
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0.0, 0.028, -0.572)
	root.add_child(muzzle)
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


static func butte_radius_at(v: float) -> float:
	# Unit butte: talus fan, vertical cliff, caprock overhang, flat dish. Never a cone.
	if v < 0.28:
		var t := v / 0.28
		return lerpf(1.06, 0.46, t * t)
	if v < 0.34:
		return lerpf(0.46, 0.42, (v - 0.28) / 0.06)
	if v < 0.76:
		return lerpf(0.42, 0.392, (v - 0.34) / 0.42)
	if v < 0.83:
		return lerpf(0.392, 0.50, (v - 0.76) / 0.07)
	if v < 0.91:
		return lerpf(0.50, 0.43, (v - 0.83) / 0.08)
	return lerpf(0.43, 0.38, (v - 0.91) / 0.09)


static func butte_mesh(seed: int, scale: Vector3, segs: int = 24, rings: int = 14) -> ArrayMesh:
	var key := "butte_%d_%.3f_%.3f_%.3f_%d_%d" % [seed, scale.x, scale.y, scale.z, segs, rings]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[Vector3] = []
	var n1 := _n3(Vector3(0.22, 0.08, 0.41), seed)
	var n2 := _n3(Vector3(0.71, 0.33, -0.18), seed + 5)
	for r in range(rings + 1):
		var v := float(r) / float(rings)
		for s in segs:
			var u := float(s) / float(segs)
			var ang := u * TAU
			var lobe := 1.0 + 0.15 * sin(ang * 2.0 + n1 * 6.1) + 0.08 * sin(ang * 5.0 - n2 * 4.2)
			var gully := 1.0 - 0.08 * pow(maxf(0.0, cos(ang - n1 * 3.7)), 4.0)
			var rad := butte_radius_at(v) * lobe * gully
			var y := v
			if v > 0.90:
				y -= (v - 0.90) * 0.14
			if v > 0.34 and v < 0.76:
				rad += 0.014 * sin(v * 44.0 + n2 * 3.0)
				y += 0.005 * sin(v * 44.0)
			pts.append(Vector3(cos(ang) * rad * scale.x, y * scale.y, sin(ang) * rad * scale.z))
	for r in rings:
		for s in segs:
			var i0 := r * segs + s
			var i1 := r * segs + ((s + 1) % segs)
			var i2 := (r + 1) * segs + s
			var i3 := (r + 1) * segs + ((s + 1) % segs)
			_tri(st, pts[i0], pts[i2], pts[i1])
			_tri(st, pts[i1], pts[i2], pts[i3])
	var center := Vector3(0.0, 0.88 * scale.y, 0.0)
	for s in segs:
		var i0 := rings * segs + s
		var i1 := rings * segs + ((s + 1) % segs)
		_tri(st, pts[i0], center, pts[i1])
	st.generate_normals()
	var mesh := st.commit()
	_mesh_cache[key] = mesh
	return mesh


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
