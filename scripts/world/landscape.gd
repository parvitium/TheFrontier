class_name Landscape
extends RefCounted

## One badlands basin: playable floor, carved washes, dunes, mesas to the horizon.

const WORLD_SIZE := 520.0
const PLAY_RADIUS := 38.0
const GRID := 84
const MAP_COLLISION := 72.0


static func height_at(x: float, z: float) -> float:
	var r := sqrt(x * x + z * z)
	var n1 := _vnoise(x, z, 0.028)
	var n2 := _vnoise(x + 40.0, z - 19.0, 0.07)
	var n3 := _vnoise(x * 0.45, z * 0.45, 0.016)
	var ridge := absf(n2 * 2.0 - 1.0)
	var wash := 0.0
	for i in 6:
		var ang := float(i) * 0.95 + 0.35
		var d := absf(x * sin(ang) - z * cos(ang))
		var along := x * cos(ang) + z * sin(ang)
		if along > -8.0:
			wash += exp(-d * d / 22.0) * 0.42 * smoothstep(-8.0, 18.0, along)
	var basin := (n1 - 0.5) * 0.18 - wash * 0.34
	var edge := _smooth(PLAY_RADIUS - 2.0, PLAY_RADIUS + 16.0, r)
	var dunes := (n1 * 0.45 + ridge * 1.15 + n3 * 1.6) * edge
	var rise := _smooth(PLAY_RADIUS, 95.0, r) * 4.2 + _smooth(95.0, 190.0, r) * 9.5
	var mesa := _mesa_field(x, z)
	var rim := _smooth(WORLD_SIZE * 0.40, WORLD_SIZE * 0.50, r) * 36.0
	if r < PLAY_RADIUS:
		return basin
	return basin * (1.0 - edge) + rise + dunes * 2.4 + mesa + rim


static func build(root: Node3D, with_collision: bool = true) -> void:
	var holder := Node3D.new()
	holder.name = "Landscape"
	root.add_child(holder)
	_terrain_mesh(holder)
	if with_collision:
		_playfield_collision(holder)
	_buttes(holder)
	_banks(holder)
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
	var sx := rng.randf_range(0.7, 1.85)
	var sy := rng.randf_range(0.55, 1.35)
	var sz := rng.randf_range(0.7, 1.75)
	inst.scale = Vector3(sx, sy, sz)
	inst.rotation = Vector3(rng.randf_range(-0.22, 0.22), rng.randf_range(0.0, TAU), rng.randf_range(-0.16, 0.16))
	inst.position = Vector3(pos.x, ground_y - sy * 0.12, pos.z)
	parent.add_child(inst)
	_dust_skirt(parent, Vector3(pos.x, ground_y + 0.02, pos.z), maxf(sx, sz) * 1.15, sy)
	if collide:
		var body := StaticBody3D.new()
		body.name = "RockCol_%d" % seed
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = Vector3(pos.x, ground_y + sy * 0.35, pos.z)
		var col := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = maxf(sx, sz) * 0.55
		col.shape = shape
		body.add_child(col)
		parent.add_child(body)
	return inst


static func _terrain_mesh(parent: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n: int = GRID
	var size := WORLD_SIZE
	var step := size / float(n)
	var origin := -size * 0.5
	for z in n:
		for x in n:
			var x0 := origin + float(x) * step
			var z0 := origin + float(z) * step
			var x1 := x0 + step
			var z1 := z0 + step
			var p00 := Vector3(x0, height_at(x0, z0), z0)
			var p10 := Vector3(x1, height_at(x1, z0), z0)
			var p01 := Vector3(x0, height_at(x0, z1), z1)
			var p11 := Vector3(x1, height_at(x1, z1), z1)
			_add_tri(st, p00, p10, p11)
			_add_tri(st, p00, p11, p01)
	st.generate_normals()
	st.generate_tangents()
	var mesh := st.commit()
	var visual := MeshInstance3D.new()
	visual.name = "Terrain"
	visual.mesh = mesh
	visual.material_override = PbrLibrary.terrain()
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(visual)


static func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n: Vector3 = (b - a).cross(c - a)
	if n.length_squared() < 1e-8:
		n = Vector3.UP
	else:
		n = n.normalized()
	st.set_normal(n)
	st.set_uv(Vector2(a.x, a.z) * 0.02)
	st.add_vertex(a)
	st.set_normal(n)
	st.set_uv(Vector2(b.x, b.z) * 0.02)
	st.add_vertex(b)
	st.set_normal(n)
	st.set_uv(Vector2(c.x, c.z) * 0.02)
	st.add_vertex(c)


static func _playfield_collision(parent: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "Ground"
	body.collision_layer = 1
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(MAP_COLLISION, 1.0, MAP_COLLISION)
	col.shape = shape
	col.position.y = -0.5
	body.add_child(col)
	parent.add_child(body)


static func _buttes(parent: Node3D) -> void:
	var specs: Array[Vector4] = [
		Vector4(78, 22, -96, 18),
		Vector4(-110, 26, -64, 22),
		Vector4(124, 30, 48, 20),
		Vector4(-86, 20, 118, 16),
		Vector4(42, 34, 156, 24),
		Vector4(-168, 38, 22, 28),
		Vector4(176, 28, -132, 26),
		Vector4(-48, 42, -178, 30),
		Vector4(210, 36, 88, 22),
		Vector4(-194, 32, -154, 24),
		Vector4(18, 48, 214, 34),
		Vector4(-220, 40, 140, 28),
	]
	for i in specs.size():
		var s: Vector4 = specs[i]
		_butte(parent, Vector3(s.x, 0, s.z), s.w, s.y, 30 + i * 17)


static func _butte(parent: Node3D, pos: Vector3, radius: float, height: float, seed: int) -> void:
	var y0 := height_at(pos.x, pos.z)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for k in 5:
		var chunk := VisualKit.instance(["rock_a", "rock_b", "rock_c"][k % 3])
		if chunk == null:
			continue
		var ox := rng.randf_range(-radius * 0.35, radius * 0.35)
		var oz := rng.randf_range(-radius * 0.35, radius * 0.35)
		var sc := radius * rng.randf_range(0.085, 0.14)
		chunk.scale = Vector3(sc, height * rng.randf_range(0.045, 0.07), sc * rng.randf_range(0.8, 1.2))
		chunk.rotation = Vector3(rng.randf_range(-0.12, 0.12), rng.randf() * TAU, rng.randf_range(-0.1, 0.1))
		chunk.position = Vector3(pos.x + ox, y0 - 1.2 + float(k) * 0.15, pos.z + oz)
		parent.add_child(chunk)
	_dust_skirt(parent, Vector3(pos.x, y0 + 0.04, pos.z), radius * 1.5, height * 0.2)


static func _banks(parent: Node3D) -> void:
	var specs: Array[Vector4] = [
		Vector4(22, 2.4, -28, 10),
		Vector4(-26, 2.1, -18, 9),
		Vector4(30, 2.8, 12, 11),
		Vector4(-18, 2.2, 26, 8),
		Vector4(8, 3.2, -36, 12),
		Vector4(-34, 2.6, 6, 10),
		Vector4(36, 3.6, -8, 13),
		Vector4(-12, 2.0, -32, 9),
	]
	for i in specs.size():
		var s: Vector4 = specs[i]
		var y0 := height_at(s.x, s.z)
		var rng := RandomNumberGenerator.new()
		rng.seed = 440 + i * 9
		for k in 4:
			var inst := VisualKit.instance(["rock_a", "rock_b", "rock_c"][(i + k) % 3])
			if inst == null:
				continue
			var ox := rng.randf_range(-s.w * 0.35, s.w * 0.35)
			var oz := rng.randf_range(-2.2, 2.2)
			inst.scale = Vector3(rng.randf_range(1.1, 1.8), rng.randf_range(0.9, 1.6), rng.randf_range(1.2, 2.0))
			inst.rotation = Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, rng.randf_range(-0.12, 0.12))
			inst.position = Vector3(s.x + ox, y0 - 0.2, s.z + oz)
			parent.add_child(inst)
		_dust_skirt(parent, Vector3(s.x, y0 + 0.03, s.z), s.w * 0.7, s.y)


static func _dressing(parent: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1103
	var pebble := KitFactory.pebble_mesh()
	var pebbles := MultiMeshInstance3D.new()
	pebbles.name = "Pebbles"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = pebble
	mm.instance_count = 420
	pebbles.multimesh = mm
	pebbles.material_override = PbrLibrary.rock(Color(0.8, 0.72, 0.6))
	parent.add_child(pebbles)
	for i in mm.instance_count:
		var r := rng.randf_range(4.0, 210.0)
		var a := rng.randf() * TAU
		var x := cos(a) * r
		var z := sin(a) * r
		var y := height_at(x, z)
		var xf := Transform3D()
		var s := rng.randf_range(0.12, 0.55)
		xf = xf.scaled(Vector3(s, s * rng.randf_range(0.35, 0.7), s))
		xf = xf.rotated(Vector3.UP, rng.randf() * TAU)
		xf.origin = Vector3(x, y + 0.01, z)
		mm.set_instance_transform(i, xf)
	var scrub_mesh := KitFactory.scrub_mesh()
	var scrub := MultiMeshInstance3D.new()
	scrub.name = "Scrub"
	var sm := MultiMesh.new()
	sm.transform_format = MultiMesh.TRANSFORM_3D
	sm.mesh = scrub_mesh
	sm.instance_count = 260
	scrub.multimesh = sm
	scrub.material_override = PbrLibrary.scrub()
	parent.add_child(scrub)
	for i in sm.instance_count:
		var r := rng.randf_range(6.0, 190.0)
		var a := rng.randf() * TAU
		var x := cos(a) * r
		var z := sin(a) * r
		if height_at(x, z) > 22.0:
			x *= 0.4
			z *= 0.4
		var y := height_at(x, z)
		var xf := Transform3D()
		var s := rng.randf_range(0.45, 1.35)
		xf = xf.scaled(Vector3(s, s * rng.randf_range(0.7, 1.3), s))
		xf = xf.rotated(Vector3.UP, rng.randf() * TAU)
		xf.origin = Vector3(x, y, z)
		sm.set_instance_transform(i, xf)
	_decals(parent, rng)


static func _decals(parent: Node3D, rng: RandomNumberGenerator) -> void:
	for i in 16:
		var r := rng.randf_range(3.0, 70.0)
		var a := rng.randf() * TAU
		var x := cos(a) * r
		var z := sin(a) * r
		var y := height_at(x, z)
		var patch := MeshInstance3D.new()
		patch.name = "Wash_%d" % i
		var mesh := CylinderMesh.new()
		var span := rng.randf_range(1.6, 4.8)
		mesh.top_radius = span
		mesh.bottom_radius = span * rng.randf_range(1.05, 1.25)
		mesh.height = 0.06
		mesh.radial_segments = 8
		patch.mesh = mesh
		patch.position = Vector3(x, y + 0.03, z)
		patch.rotate_y(rng.randf() * TAU)
		patch.scale = Vector3(1.0, 1.0, rng.randf_range(0.55, 1.15))
		patch.material_override = PbrLibrary.dust() if i % 3 else PbrLibrary.dirt(Color(0.72, 0.56, 0.4))
		patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(patch)


static func _cover_rocks(parent: Node3D) -> void:
	var spots := [
		Vector3(12, 0, 8), Vector3(-14, 0, 11), Vector3(18, 0, -16),
		Vector3(-20, 0, -12), Vector3(8, 0, -22), Vector3(-9, 0, 20),
		Vector3(24, 0, 6), Vector3(-26, 0, -4), Vector3(16, 0, 22),
		Vector3(-17, 0, -21), Vector3(30, 0, -8), Vector3(-32, 0, 10),
		Vector3(6, 0, 32), Vector3(-4, 0, -30), Vector3(36, 0, 18),
		Vector3(-38, 0, -16), Vector3(48, 0, -28), Vector3(-52, 0, 24),
		Vector3(62, 0, 40), Vector3(-70, 0, -36),
		Vector3(5.5, 0, -3.5), Vector3(-6.5, 0, -2.2), Vector3(3.8, 0, -7.5),
		Vector3(-4.2, 0, 4.8), Vector3(9.5, 0, -5.0), Vector3(-8.8, 0, -8.0),
	]
	for i in spots.size():
		plant_rock(parent, spots[i], 200 + i * 13, i < 8)


static func _horizon_scrub(parent: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 18:
		var a := float(i) / 18.0 * TAU + 0.2
		var r := rng.randf_range(88.0, 150.0)
		plant_rock(parent, Vector3(cos(a) * r, 0, sin(a) * r), 900 + i * 21, false)


static func _dust_skirt(parent: Node3D, pos: Vector3, radius: float, _hint_h: float) -> void:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.15
	mesh.height = 0.07
	mesh.radial_segments = 10
	mesh.rings = 0
	mi.mesh = mesh
	mi.material_override = PbrLibrary.dust()
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


static func _mesa_field(x: float, z: float) -> float:
	var h := 0.0
	var mesas: Array[Vector4] = [
		Vector4(78, 14, -96, 20),
		Vector4(-110, 16, -64, 24),
		Vector4(124, 18, 48, 22),
		Vector4(-86, 12, 118, 18),
		Vector4(42, 20, 156, 26),
		Vector4(-168, 22, 22, 30),
		Vector4(176, 16, -132, 28),
		Vector4(-48, 24, -178, 32),
	]
	for m in mesas:
		var dx := x - m.x
		var dz := z - m.z
		var md := sqrt(dx * dx + dz * dz)
		var top := 1.0 - _smooth(m.w * 0.55, m.w, md)
		h = maxf(h, top * m.y)
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
