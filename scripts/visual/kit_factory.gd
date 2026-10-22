class_name KitFactory
extends RefCounted

## Runtime sci-fi / badlands kit. Named nodes keep VisualKit / combat hooks working.


static func build(slot: String) -> Node3D:
	match slot:
		"core_engine":
			return _core()
		"building_wall":
			return _wall()
		"building_turret":
			return _turret()
		"building_trap":
			return _trap()
		"building_repair_beacon":
			return _beacon()
		"building_escape_ship":
			return _ship()
		"storage_tank":
			return _tank()
		"pulse_rifle":
			return _rifle()
		"scatter_cannon":
			return _shotgun()
		"rock_a":
			return _rock(11, Vector3(1.35, 0.85, 1.1))
		"rock_b":
			return _rock(27, Vector3(1.7, 1.05, 1.25))
		"rock_c":
			return _rock(43, Vector3(1.05, 0.7, 1.45))
		_:
			return null


static func pebble_mesh() -> ArrayMesh:
	return _rock_array(91, Vector3(1, 0.55, 1), 7, 5)


static func scrub_mesh() -> ArrayMesh:
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
	return st.commit()


static func _core() -> Node3D:
	var root := Node3D.new()
	root.name = "core_engine"
	# Grounded foundation: wide pad, ring, bolts, buried slightly.
	_cyl(root, "Foundation", 2.65, 0.28, Vector3(0, 0.04, 0), "Concrete", 20)
	_cyl(root, "FoundationLip", 2.72, 0.06, Vector3(0, 0.18, 0), "Metal", 20)
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
	_cyl(root, "PadInset", 2.15, 0.05, Vector3(0, 0.16, 0), "DarkMetal", 16)
	for i in 8:
		var a := float(i) / 8.0 * TAU
		_cyl(root, "PadBolt%d" % i, 0.07, 0.08, Vector3(cos(a) * 2.35, 0.2, sin(a) * 2.35), "Rust", 8)
		_box(root, "Cable%d" % i, Vector3(0.08, 0.06, 0.55), Vector3(cos(a) * 1.9, 0.18, sin(a) * 1.9), "Rust", Vector3(0, a, 0))
	_cyl(root, "Pedestal", 1.42, 0.85, Vector3(0, 0.58, 0), "Concrete", 18)
	_cyl(root, "Ring", 1.58, 0.14, Vector3(0, 1.02, 0), "Metal", 18)
	_cyl(root, "Collar", 0.62, 0.22, Vector3(0, 1.16, 0), "DarkMetal", 14)
	_cyl(root, "Coil", 0.4, 2.05, Vector3(0, 2.2, 0), "PaintedMetal", 16)
	for i in 6:
		var a := float(i) / 6.0 * TAU
		_box(root, "Fin%d" % i, Vector3(0.07, 1.55, 0.42), Vector3(cos(a) * 0.62, 2.15, sin(a) * 0.62), "Metal", Vector3(0, a, 0))
	for i in 8:
		var a := float(i) / 8.0 * TAU
		_box(root, "Strip%d" % i, Vector3(0.05, 1.35, 0.05), Vector3(cos(a) * 0.44, 2.15, sin(a) * 0.44), "EmissiveCyan")
	for i in 3:
		var a: float = [0.4, 2.2, 4.0][i]
		_cyl(root, "Pipe%d" % i, 0.07, 1.6, Vector3(cos(a) * 1.2, 1.35, sin(a) * 1.2), "Rust", 8)
		_sphere(root, "Elbow%d" % i, 0.1, Vector3(cos(a) * 1.2, 2.15, sin(a) * 1.2), "Rust", 8)
	var heart := _sphere(root, "Heart", 0.58, Vector3(0, 3.32, 0), "EmissiveAmber", 20)
	heart.name = "Heart"
	_cyl(root, "Cap", 0.5, 0.14, Vector3(0, 3.9, 0), "Metal", 14)
	return root


static func _wall() -> Node3D:
	var root := Node3D.new()
	root.name = "wall"
	_box(root, "Plinth", Vector3(2.16, 0.28, 2.16), Vector3(0, 0.12, 0), "Concrete")
	_box(root, "PlinthLip", Vector3(2.22, 0.06, 2.22), Vector3(0, 0.27, 0), "Metal")
	_box(root, "Hull", Vector3(1.78, 1.78, 1.78), Vector3(0, 1.18, 0), "Concrete")
	_box(root, "Cap", Vector3(2.08, 0.16, 2.08), Vector3(0, 2.18, 0), "Metal")
	_box(root, "CapLip", Vector3(2.18, 0.06, 2.18), Vector3(0, 2.28, 0), "DarkMetal")
	_box(root, "RoofVent", Vector3(0.42, 0.22, 0.42), Vector3(0.35, 2.38, 0.25), "DarkMetal")
	_box(root, "RoofRail", Vector3(1.4, 0.08, 0.08), Vector3(0.0, 2.36, -0.7), "Metal")
	_box(root, "RoofPipe", Vector3(0.1, 0.45, 0.1), Vector3(-0.45, 2.48, 0.4), "Rust")
	# Four faces: dark frame + two inset plates so seams read from 20 m.
	var faces: Array[Vector3] = [
		Vector3(0, 1.18, 0.92), Vector3(0, 0, 0),
		Vector3(0, 1.18, -0.92), Vector3(0, PI, 0),
		Vector3(0.92, 1.18, 0), Vector3(0, -PI * 0.5, 0),
		Vector3(-0.92, 1.18, 0), Vector3(0, PI * 0.5, 0),
	]
	for i in 4:
		var pos: Vector3 = faces[i * 2]
		var rot: Vector3 = faces[i * 2 + 1]
		_box(root, "Frame%d" % i, Vector3(1.72, 1.62, 0.1), pos, "DarkMetal", rot)
		_box(root, "PanelA%d" % i, Vector3(0.72, 1.28, 0.08), pos + Vector3(-0.4, 0.02, 0.04).rotated(Vector3.UP, rot.y), "PaintedMetal", rot)
		_box(root, "PanelB%d" % i, Vector3(0.72, 1.28, 0.08), pos + Vector3(0.4, 0.02, 0.04).rotated(Vector3.UP, rot.y), "PaintedMetal", rot)
		_box(root, "Wear%d" % i, Vector3(0.62, 0.42, 0.07), pos + Vector3(0.42 if i % 2 == 0 else -0.38, -0.52, 0.05).rotated(Vector3.UP, rot.y), "Rust", rot)
	for i in 4:
		var a := float(i) * PI * 0.5 + PI * 0.25
		_box(root, "Trim%d" % i, Vector3(0.16, 2.05, 0.16), Vector3(cos(a) * 1.0, 1.16, sin(a) * 1.0), "Metal")
	_box(root, "Vent", Vector3(0.78, 0.48, 0.1), Vector3(0, 1.55, 1.0), "DarkMetal")
	for i in 4:
		_box(root, "Slat%d" % i, Vector3(0.68, 0.04, 0.04), Vector3(0, 1.38 + float(i) * 0.09, 1.06), "Metal")
	_box(root, "LiteL", Vector3(0.4, 0.09, 0.09), Vector3(-0.52, 2.02, 1.02), "EmissiveCyan")
	_box(root, "LiteR", Vector3(0.4, 0.09, 0.09), Vector3(0.52, 2.02, 1.02), "EmissiveCyan")
	for i in 8:
		var x := -0.7 + float(i % 4) * 0.46
		var y := 0.55 + float(i / 4) * 1.15
		_cyl(root, "Bolt%d" % i, 0.04, 0.08, Vector3(x, y, 1.04), "Metal", 6, Vector3(PI * 0.5, 0, 0))
	return root


static func _turret() -> Node3D:
	var root := Node3D.new()
	root.name = "turret"
	_cyl(root, "Base", 0.7, 0.28, Vector3(0, 0.14, 0), "Concrete", 16)
	_cyl(root, "Skirt", 0.78, 0.08, Vector3(0, 0.04, 0), "Metal", 16)
	_cyl(root, "Pole", 0.13, 0.82, Vector3(0, 0.68, 0), "DarkMetal", 12)
	_box(root, "Crate", Vector3(0.42, 0.22, 0.28), Vector3(0.38, 0.22, 0.0), "PaintedMetal")
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 1.12, 0)
	root.add_child(head)
	_box(head, "Housing", Vector3(0.58, 0.34, 0.5), Vector3(0, 0, 0), "PaintedMetal")
	_box(head, "Rail", Vector3(0.12, 0.06, 0.42), Vector3(0, 0.2, 0), "Metal")
	_cyl(head, "Barrel", 0.065, 0.92, Vector3(0, 0.02, -0.55), "Metal", 12, Vector3(-PI * 0.5, 0, 0))
	_cyl(head, "BarrelB", 0.045, 0.58, Vector3(0.12, -0.06, -0.42), "DarkMetal", 10, Vector3(-PI * 0.5, 0, 0))
	_cyl(head, "Brake", 0.08, 0.1, Vector3(0, 0.02, -1.0), "DarkMetal", 10, Vector3(-PI * 0.5, 0, 0))
	_sphere(head, "Optic", 0.07, Vector3(0, 0.12, -0.18), "EmissiveCyan", 10)
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, 0.02, -1.08)
	head.add_child(muzzle)
	return root


static func _trap() -> Node3D:
	var root := Node3D.new()
	root.name = "trap"
	_box(root, "Pad", Vector3(1.9, 0.1, 1.9), Vector3(0, 0.05, 0), "DarkMetal")
	_box(root, "Grate", Vector3(1.62, 0.04, 1.62), Vector3(0, 0.11, 0), "Metal")
	for i in 9:
		var x := float(i % 3 - 1) * 0.45
		var z := float(i / 3 - 1) * 0.45
		_cone(root, "Spike%d" % i, 0.065, 0.4, Vector3(x, 0.32, z), "Rust")
	for p in [Vector3(0.82, 0.14, 0.82), Vector3(-0.82, 0.14, 0.82), Vector3(0.82, 0.14, -0.82), Vector3(-0.82, 0.14, -0.82)]:
		_box(root, "Warn%s" % str(p), Vector3(0.12, 0.08, 0.12), p, "EmissiveRed")
	return root


static func _beacon() -> Node3D:
	var root := Node3D.new()
	root.name = "repair_beacon"
	_cyl(root, "Foot", 0.58, 0.14, Vector3(0, 0.07, 0), "Concrete", 14)
	_cyl(root, "Stem", 0.09, 1.2, Vector3(0, 0.72, 0), "Metal", 10)
	_cyl(root, "Dish", 0.7, 0.1, Vector3(0, 1.4, 0), "PaintedMetal", 16)
	_sphere(root, "Hub", 0.15, Vector3(0, 1.48, 0), "EmissiveCyan", 10)
	_cyl(root, "Halo", 0.38, 0.05, Vector3(0, 1.6, 0), "EmissiveCyan", 14)
	return root


static func _ship() -> Node3D:
	var root := Node3D.new()
	root.name = "escape_ship"
	_box(root, "Hull", Vector3(3.35, 0.95, 1.62), Vector3(0, 0.82, 0), "PaintedMetal")
	_box(root, "HullPanel", Vector3(2.4, 0.08, 1.5), Vector3(0.1, 1.28, 0), "Metal")
	_box(root, "Nose", Vector3(1.05, 0.62, 1.05), Vector3(1.85, 0.8, 0), "Metal")
	_box(root, "Cabin", Vector3(1.05, 0.48, 1.1), Vector3(0.35, 1.42, 0), "Glass")
	_box(root, "Fin", Vector3(0.16, 1.25, 0.62), Vector3(-1.4, 1.5, 0), "DarkMetal")
	_cyl(root, "EngineL", 0.2, 0.5, Vector3(-1.7, 0.68, 0.42), "Metal", 10, Vector3(0, 0, PI * 0.5))
	_cyl(root, "EngineR", 0.2, 0.5, Vector3(-1.7, 0.68, -0.42), "Metal", 10, Vector3(0, 0, PI * 0.5))
	_sphere(root, "GlowL", 0.16, Vector3(-2.0, 0.68, 0.42), "EmissiveAmber", 8)
	_sphere(root, "GlowR", 0.16, Vector3(-2.0, 0.68, -0.42), "EmissiveAmber", 8)
	_box(root, "Strut", Vector3(0.12, 0.14, 1.55), Vector3(0.15, 0.28, 0), "Rust")
	_box(root, "Wear", Vector3(0.8, 0.2, 0.06), Vector3(0.6, 0.55, 0.8), "Rust")
	return root


static func _tank() -> Node3D:
	var root := Node3D.new()
	root.name = "storage_tank"
	_cyl(root, "Body", 0.82, 2.25, Vector3(0, 1.2, 0), "PaintedMetal", 18)
	_cyl(root, "Band", 0.86, 0.1, Vector3(0, 1.55, 0), "Metal", 18)
	_cyl(root, "BandB", 0.86, 0.1, Vector3(0, 0.85, 0), "Metal", 18)
	_sphere(root, "Dome", 0.82, Vector3(0, 2.32, 0), "Metal", 14)
	_cyl(root, "Pipe", 0.1, 1.25, Vector3(0.92, 0.85, 0), "Rust", 8)
	_box(root, "Valve", Vector3(0.26, 0.18, 0.26), Vector3(0.92, 1.55, 0), "DarkMetal")
	_box(root, "Stripe", Vector3(1.7, 0.16, 0.1), Vector3(0, 1.5, 0), "EmissiveAmber")
	_box(root, "Ladder", Vector3(0.08, 1.6, 0.22), Vector3(0, 1.1, 0.86), "Metal")
	return root


static func _rifle() -> Node3D:
	# Camera-space rifle: barrel along -Z, stock +Z, sit lower-right in frame.
	var root := Node3D.new()
	root.name = "pulse_rifle"
	_box(root, "Stock", Vector3(0.052, 0.078, 0.17), Vector3(0.0, 0.012, 0.24), "Polymer")
	_box(root, "StockPad", Vector3(0.058, 0.09, 0.032), Vector3(0.0, 0.012, 0.33), "Rubber")
	_box(root, "Receiver", Vector3(0.062, 0.09, 0.2), Vector3(0.0, 0.028, 0.05), "Metal")
	_box(root, "Rail", Vector3(0.028, 0.016, 0.18), Vector3(0.0, 0.082, 0.02), "DarkMetal")
	_box(root, "Grip", Vector3(0.042, 0.12, 0.048), Vector3(0.0, -0.08, 0.09), "Polymer")
	_box(root, "TriggerGuard", Vector3(0.032, 0.042, 0.055), Vector3(0.0, -0.042, 0.035), "DarkMetal")
	_box(root, "Mag", Vector3(0.036, 0.14, 0.055), Vector3(0.0, -0.11, 0.0), "DarkMetal")
	_box(root, "Handguard", Vector3(0.055, 0.058, 0.18), Vector3(0.0, 0.016, -0.15), "Polymer")
	_cyl(root, "Barrel", 0.016, 0.3, Vector3(0.0, 0.024, -0.38), "Metal", 10, Vector3(-PI * 0.5, 0, 0))
	_cyl(root, "MuzzleBrake", 0.02, 0.04, Vector3(0.0, 0.024, -0.54), "DarkMetal", 8, Vector3(-PI * 0.5, 0, 0))
	_box(root, "RearSight", Vector3(0.018, 0.022, 0.018), Vector3(0.0, 0.09, 0.12), "DarkMetal")
	_box(root, "FrontSight", Vector3(0.012, 0.026, 0.012), Vector3(0.0, 0.07, -0.3), "DarkMetal")
	_cyl(root, "Optic", 0.012, 0.055, Vector3(0.0, 0.092, 0.02), "EmissiveCyan", 8, Vector3(-PI * 0.5, 0, 0))
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0.0, 0.024, -0.58)
	root.add_child(muzzle)
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
	mi.mesh = _rock_array(seed, scale, 11, 7)
	mi.material_override = PbrLibrary.rock(Color(0.84, 0.76, 0.64))
	root.add_child(mi)
	return root


static func _rock_array(seed: int, scale: Vector3, segs: int, rings: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[Vector3] = []
	for r in range(rings + 1):
		var v := float(r) / float(rings)
		var phi := v * PI
		for s in segs:
			var u := float(s) / float(segs)
			var th := u * TAU
			var p := Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th))
			p *= Vector3(
				scale.x * rng.randf_range(0.72, 1.16),
				scale.y * rng.randf_range(0.5, 1.02),
				scale.z * rng.randf_range(0.72, 1.16)
			)
			p += Vector3(rng.randf_range(-0.07, 0.07), rng.randf_range(-0.04, 0.1), rng.randf_range(-0.07, 0.07))
			if p.y < -scale.y * 0.15:
				p.y = -scale.y * 0.15
			pts.append(p)
	for r in rings:
		for s in segs:
			var i0 := r * segs + s
			var i1 := r * segs + ((s + 1) % segs)
			var i2 := (r + 1) * segs + s
			var i3 := (r + 1) * segs + ((s + 1) % segs)
			_tri(st, pts[i0], pts[i1], pts[i3])
			_tri(st, pts[i0], pts[i3], pts[i2])
	st.generate_normals()
	return st.commit()


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-10:
		n = Vector3.UP
	else:
		n = n.normalized()
	st.set_normal(n)
	st.add_vertex(a)
	st.set_normal(n)
	st.add_vertex(b)
	st.set_normal(n)
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


static func _cyl(parent: Node, name: String, radius: float, height: float, pos: Vector3, mat: String, segs: int = 12, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
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
