class_name Landscape
extends RefCounted

## One badlands basin: playable floor, carved washes, dunes, mesas to the horizon.

const WORLD_SIZE := 520.0
const PLAY_RADIUS := 38.0
const MAP_COLLISION := 72.0
const COL_VERTS := 73
const PLAY_QUADS := 80
const NEAR_SIZE := 20.0
const NEAR_QUADS := 72
const MID_SIZE := 240.0
const MID_QUADS := 56
const FAR_QUADS := 28
const FOUNDATION_SINK := 0.04


static func height_at(x: float, z: float) -> float:
	var r := sqrt(x * x + z * z)
	var n1 := _vnoise(x, z, 0.028)
	var n2 := _vnoise(x + 40.0, z - 19.0, 0.07)
	var n3 := _vnoise(x * 0.45, z * 0.45, 0.016)
	var ridge := absf(n2 * 2.0 - 1.0)
	var carved := _carved_relief(x, z)
	var pad := 1.0 - _smooth(5.8, 10.5, r)
	var basin := (n1 - 0.5) * 0.1 + carved
	basin *= 1.0 - pad * 0.94
	var ripple := (_vnoise(x + 3.0, z - 1.5, 0.82) - 0.5) * 0.055
	ripple += (_vnoise(x - 11.0, z + 7.0, 1.65) - 0.5) * 0.028
	ripple *= 1.0 - pad
	if r < PLAY_RADIUS:
		return basin + ripple
	var edge := _smooth(PLAY_RADIUS - 2.0, PLAY_RADIUS + 16.0, r)
	var dunes := (n1 * 0.45 + ridge * 1.15 + n3 * 1.6) * edge
	var rise := _smooth(PLAY_RADIUS, 95.0, r) * 4.2 + _smooth(95.0, 190.0, r) * 9.5
	var mesa := _mesa_field(x, z)
	var rim := _smooth(WORLD_SIZE * 0.40, WORLD_SIZE * 0.50, r) * 36.0
	return basin * (1.0 - edge) + rise + dunes * 2.4 + mesa + rim + ripple * (1.0 - edge) * 0.35


static func seat(pos: Vector3, extra_y: float = 0.0, sink: float = 0.0) -> Vector3:
	return Vector3(pos.x, height_at(pos.x, pos.z) + extra_y - sink, pos.z)


static func normal_at(x: float, z: float, eps: float = 0.4) -> Vector3:
	var hl := height_at(x - eps, z)
	var hr := height_at(x + eps, z)
	var hd := height_at(x, z - eps)
	var hu := height_at(x, z + eps)
	return Vector3(hl - hr, 2.0 * eps, hd - hu).normalized()


static func slope_deg(x: float, z: float) -> float:
	return rad_to_deg(acos(clampf(normal_at(x, z).y, -1.0, 1.0)))


static func col_world_xz(ix: int, iz: int) -> Vector2:
	var half := MAP_COLLISION * 0.5
	var step := MAP_COLLISION / float(COL_VERTS - 1)
	return Vector2(-half + float(ix) * step, -half + float(iz) * step)


static func make_heightmap_shape() -> HeightMapShape3D:
	var shape := HeightMapShape3D.new()
	var n: int = COL_VERTS
	shape.map_width = n
	shape.map_depth = n
	var data := PackedFloat32Array()
	data.resize(n * n)
	for iz in n:
		for ix in n:
			var xz := col_world_xz(ix, iz)
			data[iz * n + ix] = height_at(xz.x, xz.y)
	shape.map_data = data
	return shape


static func _carved_relief(x: float, z: float) -> float:
	# Dry riverbed west of the core, a second wash east, dune ridges, channel banks.
	var h := 0.0
	var river_x := -12.2 + 2.8 * sin(z * 0.09 + 0.4)
	var d0 := absf(x - river_x)
	var run0 := 1.0 - _smooth(32.0, 44.0, absf(z))
	h += (exp(-pow(d0 - 5.8, 2.0) / 8.5) * 1.08 - exp(-d0 * d0 / 22.0) * 0.72) * run0
	var river_b := 15.8 + 2.0 * sin(z * 0.07)
	var d1 := absf(x - river_b)
	var run1 := 1.0 - _smooth(28.0, 40.0, absf(z))
	h += (exp(-pow(d1 - 5.0, 2.0) / 7.0) * 0.82 - exp(-d1 * d1 / 16.0) * 0.46) * run1
	var d2 := absf(z + 14.0)
	h += exp(-pow(d2 - 6.2, 2.0) / 9.0) * 0.95
	h -= exp(-d2 * d2 / 22.0) * 0.32 * (1.0 - exp(-pow((x - 3.0) / 18.0, 2.0)))
	h += 0.7 * exp(-pow((z + 21.0) / 8.2, 2.0)) * (0.55 + 0.45 * absf(x) / 16.0)
	h += 0.48 * exp(-pow((x + 20.0) / 7.5, 2.0)) * (1.0 - 0.35 * exp(-pow(z / 18.0, 2.0)))
	h += (_vnoise(x + 9.0, z - 4.0, 0.055) - 0.5) * 0.16
	return h


static func build(root: Node3D, with_collision: bool = true) -> void:
	var holder := Node3D.new()
	holder.name = "Landscape"
	root.add_child(holder)
	_terrain_mesh(holder)
	if with_collision:
		_playfield_collision(holder)
	_mesa_debris(holder)
	_dressing(holder)
	_cover_rocks(holder)
	_horizon_scrub(holder)


static func plant_rock(parent: Node3D, pos: Vector3, seed: int, collide: bool = false) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var kinds := ["rock_a", "rock_b", "rock_c"]
	var inst := VisualKit.instance(kinds[seed % kinds.size()])
	if inst == null:
		return null
	var ground_y := height_at(pos.x, pos.z)
	var sx := rng.randf_range(0.55, 1.05)
	var sy := rng.randf_range(0.72, 1.25)
	var sz := rng.randf_range(0.55, 1.05)
	inst.scale = Vector3(sx, sy, sz)
	inst.rotation = Vector3(rng.randf_range(-0.08, 0.08), rng.randf_range(0.0, TAU), rng.randf_range(-0.06, 0.06))
	inst.position = Vector3(pos.x, ground_y - sy * 0.22, pos.z)
	parent.add_child(inst)
	_dust_skirt(parent, Vector3(pos.x, ground_y + 0.015, pos.z), maxf(sx, sz) * 0.72, sy)
	if collide:
		var body := StaticBody3D.new()
		body.name = "RockCol_%d" % seed
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = Vector3(pos.x, ground_y + sy * 0.28, pos.z)
		var col := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = maxf(sx, sz) * 0.48
		col.shape = shape
		body.add_child(col)
		parent.add_child(body)
	return inst


static func _terrain_mesh(parent: Node3D) -> void:
	var near := _grid_mesh(parent, "NearSand", NEAR_SIZE, NEAR_QUADS, 0.0, 0.18)
	near.position.y = 0.006
	_grid_mesh(parent, "Playfield", MAP_COLLISION, PLAY_QUADS, NEAR_SIZE * 0.5, 0.35)
	var mid := _grid_mesh(parent, "TerrainMid", MID_SIZE, MID_QUADS, MAP_COLLISION * 0.5, 1.1)
	mid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var far := _grid_mesh(parent, "Terrain", WORLD_SIZE, FAR_QUADS, MID_SIZE * 0.5, 3.2)
	far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_horizon_impostors(parent)


static func _grid_mesh(parent: Node3D, mesh_name: String, size: float, quads: int, skip_inner: float, n_eps: float) -> MeshInstance3D:
	var n: int = quads
	var step := size / float(n)
	var origin := -size * 0.5
	var stride := n + 1
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	verts.resize(stride * stride)
	norms.resize(stride * stride)
	uvs.resize(stride * stride)
	for iz in stride:
		for ix in stride:
			var x := origin + float(ix) * step
			var z := origin + float(iz) * step
			var i := iz * stride + ix
			verts[i] = Vector3(x, height_at(x, z), z)
			norms[i] = normal_at(x, z, n_eps)
			uvs[i] = Vector2(x, z) * 0.02
	for iz in n:
		for ix in n:
			if skip_inner > 0.0:
				var cx := origin + (float(ix) + 0.5) * step
				var cz := origin + (float(iz) + 0.5) * step
				if maxf(absf(cx), absf(cz)) <= skip_inner:
					continue
			var i00 := iz * stride + ix
			var i10 := i00 + 1
			var i01 := i00 + stride
			var i11 := i01 + 1
			indices.append(i00)
			indices.append(i10)
			indices.append(i11)
			indices.append(i00)
			indices.append(i11)
			indices.append(i01)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var st := SurfaceTool.new()
	st.create_from(mesh, 0)
	st.generate_tangents()
	mesh = st.commit()
	var visual := MeshInstance3D.new()
	visual.name = mesh_name
	visual.mesh = mesh
	visual.material_override = PbrLibrary.terrain()
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	visual.extra_cull_margin = 8.0
	parent.add_child(visual)
	return visual


static func _playfield_collision(parent: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "Ground"
	body.collision_layer = 1
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	col.name = "HeightMap"
	col.shape = make_heightmap_shape()
	body.add_child(col)
	parent.add_child(body)


# x, cap height, z, radius — one list for heightfield and debris.
const MESA_SPECS: Array[Vector4] = [
	Vector4(78, 16, -96, 22),
	Vector4(-110, 18, -64, 26),
	Vector4(124, 20, 48, 24),
	Vector4(-86, 14, 118, 20),
	Vector4(42, 22, 156, 28),
	Vector4(-168, 24, 22, 32),
	Vector4(176, 18, -132, 30),
	Vector4(-48, 26, -178, 34),
	Vector4(210, 22, 88, 24),
	Vector4(-194, 20, -154, 26),
	Vector4(18, 28, 214, 36),
	Vector4(-220, 24, 140, 30),
]


static func _mesa_debris(parent: Node3D) -> void:
	var holder := Node3D.new()
	holder.name = "MesaDressing"
	parent.add_child(holder)
	var mm_i := MultiMeshInstance3D.new()
	mm_i.name = "MesaTalusScatter"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = KitFactory.boulder_mesh(61, Vector3(1.0, 0.55, 1.0), 10, 7)
	mm.instance_count = MESA_SPECS.size() * 3
	mm_i.multimesh = mm
	mm_i.material_override = PbrLibrary.boulder()
	mm_i.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mm_i.visibility_range_end = 260.0
	mm_i.visibility_range_end_margin = 40.0
	holder.add_child(mm_i)
	var idx := 0
	var mesh: Mesh = mm.mesh
	for i in MESA_SPECS.size():
		var s: Vector4 = MESA_SPECS[i]
		var rng := RandomNumberGenerator.new()
		rng.seed = 40 + i * 19
		for k in 3:
			var ang := rng.randf() * TAU
			var rad := s.w * rng.randf_range(0.72, 1.18)
			var x := s.x + cos(ang) * rad
			var z := s.z + sin(ang) * rad
			var y := height_at(x, z)
			var sc := rng.randf_range(0.7, 1.6)
			var scl := Vector3(sc, sc * rng.randf_range(0.5, 0.8), sc * rng.randf_range(0.8, 1.2))
			mm.set_instance_transform(idx, _grounded_xf(mesh, x, y, z, scl, rng.randf() * TAU))
			idx += 1
			if k == 0:
				var mark := Node3D.new()
				mark.name = "MesaTalus%d" % i
				mark.position = Vector3(x, y - 0.08, z)
				holder.add_child(mark)


static func _dressing(parent: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1103
	_scatter_multimesh(parent, "Pebbles", KitFactory.pebble_mesh(), PbrLibrary.boulder(), 220, rng, 3.0, 34.0, 0.07, 0.22, 90.0, 0.4, 0.75)
	_scatter_multimesh(parent, "PebblesFar", KitFactory.pebble_mesh(), PbrLibrary.boulder(), 90, rng, 20.0, 160.0, 0.14, 0.42, 200.0, 0.4, 0.75)
	_scatter_multimesh(parent, "Scrub", KitFactory.scrub_mesh(), PbrLibrary.scrub(), 120, rng, 5.0, 34.0, 0.35, 0.9, 90.0, 0.75, 1.2)
	_scatter_multimesh(parent, "ScrubFar", KitFactory.scrub_mesh(), PbrLibrary.scrub(), 50, rng, 16.0, 150.0, 0.5, 1.2, 180.0, 0.75, 1.2)
	_decals(parent, rng)


static func _scatter_multimesh(parent: Node3D, mesh_name: String, mesh: Mesh, mat: Material, count: int, rng: RandomNumberGenerator, r0: float, r1: float, s0: float, s1: float, vis_end: float, y0: float = 0.4, y1: float = 0.8) -> void:
	var inst := MultiMeshInstance3D.new()
	inst.name = mesh_name
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	inst.multimesh = mm
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.visibility_range_end = vis_end
	inst.visibility_range_end_margin = 18.0
	parent.add_child(inst)
	for i in count:
		var r := rng.randf_range(r0, r1)
		var a := rng.randf() * TAU
		var x := cos(a) * r
		var z := sin(a) * r
		if height_at(x, z) > 22.0:
			x *= 0.5
			z *= 0.5
		var y := height_at(x, z)
		var s := rng.randf_range(s0, s1)
		var scl := Vector3(s, s * rng.randf_range(y0, y1), s)
		mm.set_instance_transform(i, _grounded_xf(mesh, x, y, z, scl, rng.randf() * TAU, 0.006))


static func _decals(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var inst := MultiMeshInstance3D.new()
	inst.name = "Washes"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.12
	mesh.height = 0.05
	mesh.radial_segments = 8
	mesh.rings = 0
	mm.mesh = mesh
	mm.instance_count = 8
	inst.multimesh = mm
	inst.material_override = PbrLibrary.dust()
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.visibility_range_end = 70.0
	parent.add_child(inst)
	for i in mm.instance_count:
		var r := rng.randf_range(4.0, 38.0)
		var a := rng.randf() * TAU
		var x := cos(a) * r
		var z := sin(a) * r
		var y := height_at(x, z)
		var span := rng.randf_range(1.5, 3.6)
		var xf := Transform3D()
		xf = xf.scaled(Vector3(span, 1.0, span * rng.randf_range(0.55, 1.1)))
		xf = xf.rotated(Vector3.UP, rng.randf() * TAU)
		xf.origin = Vector3(x, y + 0.025, z)
		mm.set_instance_transform(i, xf)


static func _cover_rocks(parent: Node3D) -> void:
	var spots := [
		Vector3(12, 0, 8), Vector3(-14, 0, 11), Vector3(18, 0, -16),
		Vector3(-20, 0, -12), Vector3(8, 0, -22), Vector3(-9, 0, 20),
		Vector3(24, 0, 6), Vector3(-26, 0, -4), Vector3(16, 0, 22),
		Vector3(-17, 0, -21), Vector3(30, 0, -8), Vector3(-32, 0, 10),
		Vector3(6, 0, 32), Vector3(-4, 0, -30),
		Vector3(5.5, 0, -3.5), Vector3(-6.5, 0, -2.2), Vector3(3.8, 0, -7.5),
		Vector3(-4.2, 0, 4.8), Vector3(9.5, 0, -5.0), Vector3(-8.8, 0, -8.0),
		Vector3(2.4, 0, 9.6), Vector3(-11.0, 0, 6.4), Vector3(13.2, 0, -9.5),
		Vector3(-15.5, 0, -6.8), Vector3(21.0, 0, 12.0), Vector3(-22.5, 0, 8.5),
		Vector3(4.0, 0, -14.5), Vector3(-7.2, 0, -16.0), Vector3(11.8, 0, 15.4),
	]
	var holder := Node3D.new()
	holder.name = "CoverBoulders"
	parent.add_child(holder)
	for i in spots.size():
		plant_rock(holder, spots[i], 200 + i * 13, i < 8)


static func _horizon_scrub(parent: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var inst := MultiMeshInstance3D.new()
	inst.name = "HorizonBoulders"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = KitFactory.boulder_mesh(77, Vector3(1.4, 0.7, 1.2), 8, 6)
	mm.instance_count = 16
	inst.multimesh = mm
	inst.material_override = PbrLibrary.boulder()
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.visibility_range_begin = 40.0
	inst.visibility_range_end = 220.0
	inst.visibility_range_end_margin = 30.0
	parent.add_child(inst)
	for i in mm.instance_count:
		var a := float(i) / float(mm.instance_count) * TAU + 0.2
		var r := rng.randf_range(88.0, 150.0)
		var x := cos(a) * r
		var z := sin(a) * r
		var y := height_at(x, z)
		var sc := rng.randf_range(1.4, 2.6)
		mm.set_instance_transform(i, _grounded_xf(mm.mesh, x, y, z, Vector3(sc, sc * 0.55, sc), rng.randf() * TAU))


static func _horizon_impostors(parent: Node3D) -> void:
	var inst := MultiMeshInstance3D.new()
	inst.name = "HorizonImpostors"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.55
	mesh.bottom_radius = 1.0
	mesh.height = 1.0
	mesh.radial_segments = 8
	mesh.rings = 0
	mm.mesh = mesh
	mm.instance_count = 8
	inst.multimesh = mm
	inst.material_override = PbrLibrary.terrain()
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.visibility_range_begin = 120.0
	inst.visibility_range_end = 420.0
	inst.visibility_range_begin_margin = 24.0
	inst.visibility_range_end_margin = 40.0
	parent.add_child(inst)
	var rng := RandomNumberGenerator.new()
	rng.seed = 901
	for i in mm.instance_count:
		var a := float(i) / 8.0 * TAU + 0.4
		var r := rng.randf_range(260.0, 390.0)
		var x := cos(a) * r
		var z := sin(a) * r
		var y := height_at(x, z)
		var w := rng.randf_range(14.0, 26.0)
		var h := rng.randf_range(10.0, 18.0)
		var xf := Transform3D()
		xf = xf.scaled(Vector3(w, h, w * rng.randf_range(0.7, 1.15)))
		xf.origin = Vector3(x, y + h * 0.35, z)
		mm.set_instance_transform(i, xf)


static func _grounded_xf(mesh: Mesh, x: float, ground_y: float, z: float, scl: Vector3, yaw: float, extra: float = 0.0) -> Transform3D:
	var xf := Transform3D()
	xf = xf.scaled(scl)
	xf = xf.rotated(Vector3.UP, yaw)
	var bottom := 0.0
	if mesh:
		bottom = mesh.get_aabb().position.y
	xf.origin = Vector3(x, ground_y - bottom * scl.y + extra, z)
	return xf


static func _dust_skirt(parent: Node3D, pos: Vector3, radius: float, _hint_h: float) -> void:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.18
	mesh.height = 0.07
	mesh.radial_segments = 8
	mesh.rings = 0
	mi.mesh = mesh
	mi.material_override = PbrLibrary.dust()
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


static func _mesa_field(x: float, z: float) -> float:
	var h := 0.0
	var n := _vnoise(x, z, 0.035)
	var n2 := _vnoise(x + 17.0, z - 9.0, 0.08)
	var n3 := _vnoise(x * 0.6, z * 0.6, 0.055)
	var n4 := _vnoise(x - 9.0, z + 13.0, 0.12)
	for m in MESA_SPECS:
		var dx := x - m.x + (n - 0.5) * m.w * 0.16
		var dz := z - m.z + (n2 - 0.5) * m.w * 0.16
		var md := sqrt(dx * dx + dz * dz)
		var r_top := m.w * (0.26 + n * 0.08)
		var r_cliff := m.w * (0.50 + n2 * 0.05)
		var r_talus := m.w * (1.18 + n2 * 0.08)
		var gully := pow(absf(n3 * 2.0 - 1.0), 1.45)
		var cap := m.y * (0.90 + n * 0.12)
		var land := 0.0
		if md <= r_top:
			var dish := (md / maxf(0.001, r_top))
			dish = dish * dish
			land = cap * (0.78 + n4 * 0.16 - gully * 0.30 - dish * 0.10)
		elif md <= r_cliff:
			var t := (md - r_top) / maxf(0.001, r_cliff - r_top)
			var top_h := cap * (0.78 + n4 * 0.16 - gully * 0.22)
			var foot_h := cap * 0.30
			land = lerpf(top_h, foot_h, t * t * (3.0 - 2.0 * t))
		elif md <= r_talus:
			var t := (md - r_cliff) / maxf(0.001, r_talus - r_cliff)
			var foot_h := cap * 0.30
			var apron := 1.0 - t
			land = foot_h * apron * apron * (0.85 + n2 * 0.2)
		h = maxf(h, land)
	h += (n2 - 0.5) * 0.9 * _smooth(PLAY_RADIUS + 20.0, 80.0, sqrt(x * x + z * z))
	return h


static func _hash2(ix: int, iz: int) -> float:
	var n: int = ix * 374761393 + iz * 668265263
	n = (n ^ (n >> 13)) * 1274126177
	return float(n & 0x7fffffff) / 2147483647.0


static func _vnoise(x: float, z: float, scale: float) -> float:
	var sx := x * scale
	var sz := z * scale
	var ix := int(floor(sx))
	var iz := int(floor(sz))
	var fx := sx - float(ix)
	var fz := sz - float(iz)
	var ux := fx * fx * (3.0 - 2.0 * fx)
	var uz := fz * fz * (3.0 - 2.0 * fz)
	var a := _hash2(ix, iz)
	var b := _hash2(ix + 1, iz)
	var c := _hash2(ix, iz + 1)
	var d := _hash2(ix + 1, iz + 1)
	return lerpf(lerpf(a, b, ux), lerpf(c, d, ux), uz)


static func _smooth(edge0: float, edge1: float, v: float) -> float:
	var t := clampf((v - edge0) / maxf(0.0001, edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
