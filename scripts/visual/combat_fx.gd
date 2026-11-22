class_name CombatFx
extends Node3D

## Pooled combat presentation: muzzle, tracers, elemental trails, material
## hits, hit-flash, deaths, and lingering corpses. Particle amounts are capped.
## Warmup compiles GPU particle shaders so the first player-shot-on-mob does
## not hitch the sim.

const POOL_NAME := "CombatFxPool"

const CAP_MUZZLE := 10
const CAP_SPARK := 12
const CAP_BLOOD := 14
const CAP_BONE := 10
const CAP_DUST := 12
const CAP_ELEMENT := 14
const CAP_DEATH := 18
const CAP_EXPLODE := 22
const CAP_TRAIL := 12

const POOL_MUZZLE := 6
const POOL_TRACER := 16
const POOL_IMPACT := 20
const POOL_ELEMENT := 8
const POOL_DEATH := 8
const POOL_LIGHT := 10
const POOL_DECAL := 14
const POOL_CORPSE := 10
const POOL_BOLT := 8
const POOL_FLASH := 8

const CORPSE_MIN := 8.0
const CORPSE_MAX := 10.0
const CORPSE_SINK := 1.35
const FLASH_MIN_DAMAGE := 1.5
const FLASH_COOLDOWN := 0.1

const SHADER_ADD := "res://assets/shaders/combat_particle_add.gdshader"
const SHADER_MIX := "res://assets/shaders/combat_particle_mix.gdshader"
const SHADER_TRACER := "res://assets/shaders/combat_tracer.gdshader"
const SHADER_FLASH := "res://assets/shaders/hit_flash.gdshader"

static var _shared: CombatFx
var _idle: Dictionary = {}
var _active: Array[Dictionary] = []
var _flash_cd: Dictionary = {}
var _built: bool = false
var _warmed: bool = false
var _blood_tex: Texture2D
var _sand_tex: Texture2D
var _draw: Dictionary = {}


static func pool_for(host: Node) -> CombatFx:
	if host == null:
		if is_instance_valid(_shared) and _shared.is_inside_tree():
			return _shared
		return null
	var n: Node = host
	while n:
		var found := n.get_node_or_null(POOL_NAME) as CombatFx
		if found:
			_shared = found
			return found
		n = n.get_parent()
	var tree := host.get_tree()
	var root: Node = host
	if tree and tree.current_scene:
		root = tree.current_scene
	elif tree:
		root = tree.root
	var pool := CombatFx.new()
	pool.name = POOL_NAME
	root.add_child(pool)
	pool._ensure()
	_shared = pool
	return pool


static func warmup(host: Node) -> void:
	var pool := pool_for(host)
	if pool == null or pool._warmed:
		return
	pool._warm_emit()
	pool._warmed = true


static func muzzle_flash(parent: Node3D, at: Vector3, color: Color = Color(1.0, 0.78, 0.32), shot_vfx: String = "", forward: Vector3 = Vector3.FORWARD) -> void:
	var pool := pool_for(parent)
	if pool == null:
		return
	pool.play_muzzle(at, color, FxSurface.normalize_shot(shot_vfx) if shot_vfx != "" else FxSurface.SHOT_KINETIC, forward)


static func tracer(host: Node, from: Vector3, to: Vector3, color: Color = Color(1.0, 0.82, 0.35), shot_vfx: String = "") -> void:
	var pool := pool_for(host)
	if pool == null:
		return
	pool.play_tracer(from, to, color, FxSurface.normalize_shot(shot_vfx) if shot_vfx != "" else FxSurface.SHOT_KINETIC)


static func impact(host: Node, at: Vector3, color: Color = Color(1.0, 0.7, 0.3), collider: Object = null, normal: Vector3 = Vector3.UP) -> void:
	var pool := pool_for(host)
	if pool == null:
		return
	var surface := FxSurface.of_collider(collider)
	pool.play_impact(at, normal, surface, color, FxSurface.size_scale(collider))


static func projectile_burst(host: Node, at: Vector3, shot_vfx: String) -> void:
	var pool := pool_for(host)
	if pool == null:
		return
	pool.play_element(at, FxSurface.normalize_shot(shot_vfx), 1.0)


static func hit_flash(target: Node3D, amount: float = 8.0) -> void:
	if target == null or amount < FLASH_MIN_DAMAGE:
		return
	var pool := pool_for(target)
	if pool == null:
		return
	pool.play_hit_flash(target)


static func begin_death(mob: Node3D) -> void:
	if mob == null:
		return
	var pool := pool_for(mob)
	if pool == null:
		mob.queue_free()
		return
	pool.play_death(mob)


static func dress_projectile(proj: Node3D, shot_vfx: String) -> void:
	var pool := pool_for(proj)
	if pool == null:
		return
	pool.attach_bolt(proj, FxSurface.normalize_shot(shot_vfx))


static func release_projectile(proj: Node3D) -> void:
	if proj == null or not proj.has_meta("fx_bolt"):
		return
	var pool := pool_for(proj)
	if pool == null:
		return
	pool.detach_bolt(proj)


func pooled_idle(bucket: String) -> int:
	var arr: Array = _idle.get(bucket, [])
	return arr.size()


func pooled_active(bucket: String) -> int:
	var n: int = 0
	for rec in _active:
		if str(rec.get("bucket", "")) == bucket:
			n += 1
	return n


func particle_amounts() -> Array[int]:
	var out: Array[int] = []
	for child in find_children("*", "GPUParticles3D", true, false):
		var parts := child as GPUParticles3D
		if parts:
			out.append(parts.amount)
	return out


func max_particle_amount() -> int:
	var best: int = 0
	for n in particle_amounts():
		best = maxi(best, n)
	return best


func _ready() -> void:
	_ensure()


func _process(delta: float) -> void:
	# A hitch frame (shader compile, first spawn) must not expire every FX.
	if delta > 0.08:
		return
	_tick(delta)


func _ensure() -> void:
	if _built:
		return
	_built = true
	_blood_tex = _make_splatter(Color(0.38, 0.03, 0.03, 0.95), 17)
	_sand_tex = _make_splatter(Color(0.62, 0.46, 0.28, 0.55), 9)
	_idle["muzzle"] = _make_emitters(POOL_MUZZLE, "muzzle", CAP_MUZZLE, 0.12, "add", Color(1.0, 0.72, 0.28), 8.0, false)
	_idle["impact"] = _make_emitters(POOL_IMPACT, "impact", CAP_SPARK, 0.32, "add", Color(1.0, 0.75, 0.3), 4.0, false)
	_idle["element"] = _make_emitters(POOL_ELEMENT, "element", CAP_ELEMENT, 0.4, "add", Color(1.0, 0.5, 0.15), 5.0, false)
	_idle["death"] = _make_emitters(POOL_DEATH, "death", CAP_DEATH, 0.55, "add", Color(1.0, 0.55, 0.2), 6.0, false)
	_idle["tracer"] = _make_tracers(POOL_TRACER)
	_idle["light"] = _make_lights(POOL_LIGHT)
	_idle["decal"] = _make_decals(POOL_DECAL)
	_idle["corpse"] = _make_corpses(POOL_CORPSE)
	_idle["bolt"] = _make_bolts(POOL_BOLT)
	_idle["flash"] = _make_flash_mats(POOL_FLASH)


func play_muzzle(at: Vector3, color: Color, shot_vfx: String, forward: Vector3 = Vector3.FORWARD) -> void:
	var parts := _acquire("muzzle") as GPUParticles3D
	if parts:
		_configure_muzzle(parts, shot_vfx, color)
		var aim := forward
		if aim.length() < 0.05:
			aim = Vector3.FORWARD
		_place_particles(parts, at, aim.normalized())
		_style_flash_core(parts, color)
		_kick(parts, 0.32, "muzzle")
	var light := _acquire("light") as OmniLight3D
	if light:
		_place_light(light, at, color, 8.0, 5.0)
		_kick(light, 0.22, "light")


func play_tracer(from: Vector3, to: Vector3, color: Color, shot_vfx: String) -> void:
	var mi := _acquire("tracer") as MeshInstance3D
	if mi == null:
		return
	var dir := to - from
	var len := dir.length()
	if len < 0.08:
		_recycle_node("tracer", mi)
		return
	_orient_tracer(mi, from, to, shot_vfx)
	var shot_col := color if shot_vfx == FxSurface.SHOT_KINETIC else FxSurface.shot_color(shot_vfx)
	var mat: Material = mi.material_override
	if mat is ShaderMaterial:
		var smat := mat as ShaderMaterial
		smat.set_shader_parameter("tint", shot_col)
		smat.set_shader_parameter("fade", 1.0)
		smat.set_shader_parameter("glow", 4.2 if shot_vfx == FxSurface.SHOT_SPELL else 3.1)
	elif mat is StandardMaterial3D:
		var std := mat as StandardMaterial3D
		std.albedo_color = Color(shot_col.r, shot_col.g, shot_col.b, 1.0)
		std.emission = shot_col
		std.emission_energy_multiplier = 12.0
	_kick(mi, 0.28 if shot_vfx != FxSurface.SHOT_FIRE else 0.34, "tracer")


func play_impact(at: Vector3, normal: Vector3, surface: String, color: Color, scale: float) -> void:
	var n := normal
	if n.length() < 0.05:
		n = Vector3.UP
	else:
		n = n.normalized()
	var parts := _acquire("impact") as GPUParticles3D
	if parts:
		_configure_impact(parts, surface, color, scale)
		_place_particles(parts, at, n)
		_kick(parts, 0.36, "impact")
	var light_col := color
	if surface == FxSurface.ORGANIC:
		light_col = Color(0.55, 0.08, 0.05)
	elif surface == FxSurface.SKELETAL:
		light_col = Color(0.82, 0.78, 0.62)
	elif surface == FxSurface.METAL:
		light_col = Color(1.0, 0.78, 0.4)
	else:
		light_col = Color(0.78, 0.62, 0.4)
	var light := _acquire("light") as OmniLight3D
	if light:
		_place_light(light, at, light_col, 2.6, 2.0)
		_kick(light, 0.09, "light")
	if surface == FxSurface.ORGANIC:
		_spawn_decal(at, n, _blood_tex, Color(0.42, 0.04, 0.04, 1.0), Vector3(0.55, 0.32, 0.55), 2.8)
	elif surface == FxSurface.TERRAIN:
		_spawn_decal(at, n, _sand_tex, Color(0.7, 0.52, 0.32, 1.0), Vector3(0.42, 0.22, 0.42), 1.6)


func play_element(at: Vector3, shot_vfx: String, scale: float) -> void:
	if shot_vfx == FxSurface.SHOT_KINETIC:
		return
	var parts := _acquire("element") as GPUParticles3D
	if parts == null:
		return
	_configure_element(parts, shot_vfx, scale)
	_place_particles(parts, at, Vector3.UP)
	_kick(parts, 0.42, "element")
	var light := _acquire("light") as OmniLight3D
	if light:
		_place_light(light, at, FxSurface.shot_color(shot_vfx), 3.2 * scale, 2.4)
		_kick(light, 0.12, "light")


func play_hit_flash(target: Node3D) -> void:
	var id := target.get_instance_id()
	if float(_flash_cd.get(id, 0.0)) > 0.0:
		return
	_flash_cd[id] = FLASH_COOLDOWN
	var mat := _acquire("flash") as Material
	if mat == null:
		return
	if mat is ShaderMaterial:
		(mat as ShaderMaterial).set_shader_parameter("intensity", 0.95)
	elif mat is StandardMaterial3D:
		var sm := mat as StandardMaterial3D
		sm.albedo_color = Color(1.0, 0.92, 0.78, 1.0)
		sm.emission = Color(1.0, 0.9, 0.7)
		sm.emission_energy_multiplier = 10.0
	var meshes: Array[MeshInstance3D] = []
	for child in target.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi == null:
			continue
		mi.material_overlay = mat
		meshes.append(mi)
	if meshes.is_empty():
		_recycle_node("flash", mat)
		return
	_active.append({
		bucket = "flash",
		node = mat,
		life = 0.14,
		max_life = 0.14,
		meshes = meshes,
	})


func play_death(mob: Node3D) -> void:
	var surface := FxSurface.of_collider(mob)
	var scale := FxSurface.size_scale(mob)
	var at := mob.global_position + Vector3(0.0, 0.7 * scale, 0.0)
	if mob.is_in_group("mobs"):
		mob.remove_from_group("mobs")
	if mob is CollisionObject3D:
		(mob as CollisionObject3D).collision_layer = 0
		(mob as CollisionObject3D).collision_mask = 0
	if mob is Node:
		mob.set_physics_process(false)
	var explodes := FxSurface.death_explodes(surface)
	var parts := _acquire("death") as GPUParticles3D
	if parts:
		_configure_death(parts, surface, scale, explodes)
		_place_particles(parts, at, Vector3.UP)
		_kick(parts, 0.7 if explodes else 0.5, "death")
	var light := _acquire("light") as OmniLight3D
	if light:
		var col := Color(1.0, 0.55, 0.18) if explodes else Color(0.5, 0.06, 0.04)
		if surface == FxSurface.SKELETAL:
			col = Color(0.78, 0.74, 0.58)
		_place_light(light, at, col, (7.5 if explodes else 3.2) * scale, 4.0 * scale)
		_kick(light, 0.18 if explodes else 0.12, "light")
	var visual := mob.get_node_or_null("Visual") as Node3D
	if visual:
		var xf := visual.global_transform
		mob.remove_child(visual)
		_attach_corpse(visual, xf, surface, scale, explodes)
	else:
		_attach_corpse(_make_standin(surface, scale), Transform3D(Basis.IDENTITY, mob.global_position), surface, scale, explodes)
	mob.queue_free()


func attach_bolt(proj: Node3D, shot_vfx: String) -> void:
	var bolt := _acquire("bolt") as Node3D
	if bolt == null:
		return
	_style_bolt(bolt, shot_vfx)
	if bolt.get_parent():
		bolt.get_parent().remove_child(bolt)
	proj.add_child(bolt)
	bolt.position = Vector3.ZERO
	bolt.visible = true
	var trail := bolt.get_node_or_null("Trail") as GPUParticles3D
	if trail:
		trail.emitting = true
		trail.restart()
	proj.set_meta("fx_bolt", bolt)
	var rec: Dictionary = {
		bucket = "bolt",
		node = bolt,
		life = 4.0,
		max_life = 4.0,
		held = true,
		proj = proj,
	}
	_active.append(rec)


func detach_bolt(proj: Node3D) -> void:
	if not proj.has_meta("fx_bolt"):
		return
	var bolt := proj.get_meta("fx_bolt") as Node3D
	proj.remove_meta("fx_bolt")
	if bolt == null:
		return
	var trail := bolt.get_node_or_null("Trail") as GPUParticles3D
	if trail:
		trail.emitting = false
	if bolt.get_parent() == proj:
		proj.remove_child(bolt)
	add_child(bolt)
	bolt.visible = false
	bolt.position = Vector3(0.0, -90.0, 0.0)
	_drop_active_node(bolt)
	_recycle_node("bolt", bolt)


func _tick(delta: float) -> void:
	if _flash_cd.size() > 0:
		var keys: Array = _flash_cd.keys()
		for id in keys:
			_flash_cd[id] = float(_flash_cd[id]) - delta
			if float(_flash_cd[id]) <= 0.0:
				_flash_cd.erase(id)
	if _active.is_empty():
		return
	var i: int = _active.size() - 1
	while i >= 0:
		var rec: Dictionary = _active[i]
		if bool(rec.get("held", false)):
			var proj: Variant = rec.get("proj", null)
			if proj == null or not is_instance_valid(proj):
				var held := rec.get("node") as Node
				_active.remove_at(i)
				if held is Node3D:
					_recycle_node(str(rec.bucket), held as Node3D)
			i -= 1
			continue
		rec.life = float(rec.life) - delta
		var bucket := str(rec.bucket)
		var node: Object = rec.get("node")
		if bucket == "tracer" and node is MeshInstance3D:
			var fade := clampf(float(rec.life) / maxf(float(rec.max_life), 0.001), 0.0, 1.0)
			var mat: Material = (node as MeshInstance3D).material_override
			if mat is ShaderMaterial:
				(mat as ShaderMaterial).set_shader_parameter("fade", fade)
			elif mat is StandardMaterial3D:
				var sm := mat as StandardMaterial3D
				sm.albedo_color.a = fade
				sm.emission_energy_multiplier = 12.0 * fade
		elif bucket == "light" and node is OmniLight3D:
			var light := node as OmniLight3D
			var t := clampf(float(rec.life) / maxf(float(rec.max_life), 0.001), 0.0, 1.0)
			light.light_energy = float(light.get_meta("fx_energy", 3.0)) * t
		elif bucket == "decal" and node is Decal:
			var decal := node as Decal
			var t2 := clampf(float(rec.life) / maxf(float(rec.max_life), 0.001), 0.0, 1.0)
			var base: Color = rec.get("modulate", Color.WHITE)
			decal.modulate = Color(base.r, base.g, base.b, base.a * t2)
		elif bucket == "flash":
			var intensity := clampf(float(rec.life) / maxf(float(rec.max_life), 0.001), 0.0, 1.0)
			if node is ShaderMaterial:
				(node as ShaderMaterial).set_shader_parameter("intensity", intensity * 0.95)
			elif node is StandardMaterial3D:
				(node as StandardMaterial3D).emission_energy_multiplier = 10.0 * intensity
		elif bucket == "muzzle" and node is GPUParticles3D:
			var core := (node as GPUParticles3D).get_node_or_null("FlashCore") as MeshInstance3D
			if core:
				var t := clampf(float(rec.life) / maxf(float(rec.max_life), 0.001), 0.0, 1.0)
				core.scale = Vector3.ONE * (0.45 + t * 0.9)
				var cmat := core.material_override
				if cmat is StandardMaterial3D:
					(cmat as StandardMaterial3D).emission_energy_multiplier = 14.0 * t
		elif bucket == "corpse":
			_tick_corpse(rec, delta)
		if float(rec.life) <= 0.0 and bucket != "corpse":
			_finish(rec)
			_active.remove_at(i)
		elif bucket == "corpse" and str(rec.get("phase", "")) == "done":
			_finish(rec)
			_active.remove_at(i)
		i -= 1


func _tick_corpse(rec: Dictionary, delta: float) -> void:
	var holder := rec.get("node") as Node3D
	if holder == null:
		rec.phase = "done"
		rec.life = 0.0
		return
	if str(rec.get("phase", "hold")) == "hold":
		if float(rec.life) <= 0.0:
			rec.phase = "sink"
			rec.life = CORPSE_SINK
			rec.max_life = CORPSE_SINK
		return
	holder.position.y -= delta * 0.9
	var fade := clampf(float(rec.life) / CORPSE_SINK, 0.0, 1.0)
	for child in holder.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi and mi.material_overlay is ShaderMaterial:
			(mi.material_overlay as ShaderMaterial).set_shader_parameter("intensity", fade * 0.35)
	if float(rec.life) <= 0.0:
		rec.phase = "done"


func _finish(rec: Dictionary) -> void:
	var bucket := str(rec.bucket)
	var node: Object = rec.get("node")
	if bucket == "flash":
		var meshes: Array = rec.get("meshes", [])
		for mi in meshes:
			if is_instance_valid(mi) and mi is MeshInstance3D:
				(mi as MeshInstance3D).material_overlay = null
		if node is Material:
			_recycle_node("flash", node)
		return
	if node is GPUParticles3D:
		var parts := node as GPUParticles3D
		parts.emitting = false
		var core := parts.get_node_or_null("FlashCore") as MeshInstance3D
		if core:
			core.visible = false
	if node is Node3D:
		var n3 := node as Node3D
		n3.visible = bucket == "corpse"
		if bucket == "corpse":
			_clear_corpse(n3)
			n3.visible = false
		n3.position = Vector3(0.0, -90.0, 0.0)
		_recycle_node(bucket, n3)


func _kick(node: Node, life: float, bucket: String) -> void:
	_active.append({bucket = bucket, node = node, life = life, max_life = life})


func _acquire(bucket: String) -> Variant:
	var arr: Array = _idle.get(bucket, [])
	if arr.is_empty():
		_steal(bucket)
		arr = _idle.get(bucket, [])
	if arr.is_empty():
		return null
	return arr.pop_back()


func _steal(bucket: String) -> void:
	var oldest_i: int = -1
	var oldest_life: float = INF
	for i in _active.size():
		var rec: Dictionary = _active[i]
		if str(rec.get("bucket", "")) != bucket:
			continue
		if bool(rec.get("held", false)):
			continue
		if float(rec.life) < oldest_life:
			oldest_life = float(rec.life)
			oldest_i = i
	if oldest_i < 0:
		return
	var rec2: Dictionary = _active[oldest_i]
	_active.remove_at(oldest_i)
	_finish(rec2)


func _recycle_node(bucket: String, node: Object) -> void:
	if not _idle.has(bucket):
		_idle[bucket] = []
	(_idle[bucket] as Array).append(node)


func _drop_active_node(node: Object) -> void:
	var i: int = _active.size() - 1
	while i >= 0:
		if _active[i].get("node") == node:
			_active.remove_at(i)
			return
		i -= 1


func _style_flash_core(parts: GPUParticles3D, color: Color) -> void:
	var core := parts.get_node_or_null("FlashCore") as MeshInstance3D
	if core == null:
		return
	core.visible = true
	core.scale = Vector3.ONE
	var mat := core.material_override as StandardMaterial3D
	if mat:
		mat.albedo_color = Color(color.r, color.g, color.b, 1.0)
		mat.emission = color
		mat.emission_energy_multiplier = 14.0


func _place_particles(parts: GPUParticles3D, at: Vector3, normal: Vector3) -> void:
	parts.visible = true
	parts.global_position = at
	var n := normal.normalized()
	if n.length() < 0.05:
		n = Vector3.UP
	var up := Vector3.UP
	if absf(n.dot(up)) > 0.95:
		up = Vector3.RIGHT
	parts.look_at(at + n, up)
	var proc := parts.process_material as ParticleProcessMaterial
	if proc:
		proc.direction = Vector3(0, 0, -1)
	parts.emitting = true
	parts.preprocess = 0.04
	parts.restart()


func _place_light(light: OmniLight3D, at: Vector3, color: Color, energy: float, omni_range: float) -> void:
	light.visible = true
	light.global_position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = omni_range
	light.set_meta("fx_energy", energy)


func _orient_tracer(mi: MeshInstance3D, from: Vector3, to: Vector3, shot_vfx: String) -> void:
	var dir := to - from
	var len := maxf(dir.length(), 0.08)
	var z := dir / len
	var x := Vector3.UP.cross(z)
	if x.length() < 0.05:
		x = Vector3.RIGHT.cross(z)
	x = x.normalized()
	var y := z.cross(x).normalized()
	var thick := 1.0
	match shot_vfx:
		FxSurface.SHOT_FIRE:
			thick = 1.35
		FxSurface.SHOT_ICE:
			thick = 1.25
		FxSurface.SHOT_SPELL:
			thick = 1.2
	var basis := Basis(x, y, z).scaled(Vector3(thick, thick, len))
	mi.visible = true
	mi.global_transform = Transform3D(basis, from.lerp(to, 0.5))


func _spawn_decal(at: Vector3, normal: Vector3, tex: Texture2D, modulate: Color, size: Vector3, life: float) -> void:
	var decal := _acquire("decal") as Decal
	if decal == null:
		return
	var n := normal.normalized()
	if n.length() < 0.05:
		n = Vector3.UP
	var x := n.cross(Vector3.FORWARD)
	if x.length() < 0.08:
		x = n.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(n).normalized()
	decal.visible = true
	decal.texture_albedo = tex
	decal.modulate = modulate
	decal.size = size
	decal.global_transform = Transform3D(Basis(x, n, z), at + n * 0.03)
	_active.append({bucket = "decal", node = decal, life = life, max_life = life, modulate = modulate})


func _attach_corpse(visual: Node3D, xf: Transform3D, surface: String, scale: float, explodes: bool) -> void:
	var holder := _acquire("corpse") as Node3D
	if holder == null:
		visual.queue_free()
		return
	_clear_corpse(holder)
	holder.visible = true
	if holder.get_parent() != self:
		if holder.get_parent():
			holder.get_parent().remove_child(holder)
		add_child(holder)
	visual.name = "Remains"
	holder.add_child(visual)
	holder.global_transform = Transform3D(Basis.IDENTITY, xf.origin)
	visual.transform = Transform3D(xf.basis, Vector3.ZERO)
	if explodes:
		visual.scale = Vector3.ONE * 0.35
		_scatter_wreck(holder, scale)
	elif surface == FxSurface.SKELETAL:
		visual.visible = false
		_scatter_bones(holder, scale)
	else:
		visual.rotate_object_local(Vector3.FORWARD, 1.25)
		visual.position.y = 0.1 * scale
	var linger := randf_range(CORPSE_MIN, CORPSE_MAX)
	_active.append({
		bucket = "corpse",
		node = holder,
		life = linger,
		max_life = linger,
		phase = "hold",
	})


func _clear_corpse(holder: Node3D) -> void:
	var kids: Array[Node] = holder.get_children()
	for child in kids:
		holder.remove_child(child)
		child.free()


func _scatter_bones(holder: Node3D, scale: float) -> void:
	var mat := PbrLibrary.concrete(Color(0.82, 0.78, 0.68))
	for i in 6:
		var chip := Greybox.box(Vector3(0.18, 0.07, 0.05) * scale, mat, "Bone%d" % i)
		chip.position = Vector3(randf_range(-0.28, 0.28), 0.05, randf_range(-0.28, 0.28)) * scale
		chip.rotation = Vector3(randf() * 0.8, randf() * TAU, randf() * 0.6)
		holder.add_child(chip)


func _scatter_wreck(holder: Node3D, scale: float) -> void:
	var mat := PbrLibrary.metal(Color(0.32, 0.3, 0.28), 0.7, 0.8)
	for i in 4:
		var plate := Greybox.box(Vector3(0.22, 0.04, 0.14) * scale, mat, "Wreck%d" % i)
		plate.position = Vector3(randf_range(-0.25, 0.25), 0.05, randf_range(-0.25, 0.25)) * scale
		plate.rotation = Vector3(randf() * 0.5, randf() * TAU, randf() * 0.4)
		holder.add_child(plate)


func _make_standin(surface: String, scale: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Standin"
	var col := Color(0.45, 0.1, 0.08) if surface == FxSurface.ORGANIC else Color(0.8, 0.76, 0.64)
	if surface == FxSurface.METAL or surface == FxSurface.MAGICAL:
		col = Color(0.3, 0.32, 0.34)
	root.add_child(Greybox.box(Vector3(0.5, 0.18, 0.35) * scale, PbrLibrary.flesh(col) if surface == FxSurface.ORGANIC else PbrLibrary.metal(col), "Pile"))
	return root


func _configure_muzzle(parts: GPUParticles3D, shot_vfx: String, color: Color) -> void:
	parts.amount = _cap(CAP_MUZZLE)
	parts.lifetime = 0.32
	parts.explosiveness = 0.95
	var proc := parts.process_material as ParticleProcessMaterial
	if proc == null:
		return
	proc.spread = 55.0
	proc.initial_velocity_min = 0.2
	proc.initial_velocity_max = 1.8
	proc.gravity = Vector3(0, 0.6, 0)
	proc.scale_min = 0.1
	proc.scale_max = 0.22
	proc.color = color
	match shot_vfx:
		FxSurface.SHOT_FIRE:
			proc.color = Color(1.0, 0.42, 0.1)
			proc.gravity = Vector3(0, 1.8, 0)
		FxSurface.SHOT_ICE:
			proc.color = Color(0.7, 0.88, 1.0)
			proc.gravity = Vector3(0, 0.05, 0)
			proc.initial_velocity_max = 2.4
		FxSurface.SHOT_SPELL:
			proc.color = Color(0.4, 0.85, 1.0)
	_set_draw(parts, "add", proc.color, 6.0, Vector2(0.09, 0.09))


func _configure_impact(parts: GPUParticles3D, surface: String, color: Color, scale: float) -> void:
	var proc := parts.process_material as ParticleProcessMaterial
	if proc == null:
		return
	proc.spread = 48.0
	proc.gravity = Vector3(0, -9.0, 0)
	proc.scale_min = 0.03 * scale
	proc.scale_max = 0.08 * scale
	proc.particle_flag_align_y = false
	parts.lifetime = 0.32
	parts.explosiveness = 0.94
	match surface:
		FxSurface.METAL:
			parts.amount = _cap(CAP_SPARK)
			proc.color = Color(1.0, 0.78, 0.35)
			proc.initial_velocity_min = 3.5
			proc.initial_velocity_max = 8.5
			proc.gravity = Vector3(0, -14.0, 0)
			proc.spread = 55.0
			proc.particle_flag_align_y = true
			_set_draw(parts, "add", proc.color, 7.0, Vector2(0.03, 0.11))
		FxSurface.ORGANIC:
			parts.amount = _cap(CAP_BLOOD)
			proc.color = Color(0.45, 0.04, 0.04)
			proc.initial_velocity_min = 1.4
			proc.initial_velocity_max = 4.2
			proc.gravity = Vector3(0, -11.0, 0)
			parts.lifetime = 0.4
			_set_draw(parts, "mix", proc.color, 0.2, Vector2(0.09, 0.12))
		FxSurface.SKELETAL:
			parts.amount = _cap(CAP_BONE)
			proc.color = Color(0.84, 0.78, 0.62)
			proc.initial_velocity_min = 1.8
			proc.initial_velocity_max = 5.2
			proc.gravity = Vector3(0, -12.0, 0)
			proc.scale_min = 0.04 * scale
			proc.scale_max = 0.09 * scale
			_set_draw(parts, "mix", proc.color, 0.35, Vector2(0.07, 0.05))
		FxSurface.MAGICAL:
			parts.amount = _cap(CAP_ELEMENT)
			proc.color = Color(0.55, 0.72, 1.0)
			proc.initial_velocity_min = 1.2
			proc.initial_velocity_max = 3.8
			proc.gravity = Vector3(0, 0.6, 0)
			_set_draw(parts, "add", proc.color, 5.5, Vector2(0.06, 0.06))
		_:
			parts.amount = _cap(CAP_DUST)
			proc.color = Color(0.72, 0.55, 0.34)
			proc.initial_velocity_min = 0.8
			proc.initial_velocity_max = 3.1
			proc.gravity = Vector3(0, -4.5, 0)
			parts.lifetime = 0.48
			_set_draw(parts, "mix", proc.color, 0.05, Vector2(0.14, 0.14))
	if surface == FxSurface.METAL:
		proc.color = proc.color.lerp(color, 0.15)


func _configure_element(parts: GPUParticles3D, shot_vfx: String, scale: float) -> void:
	var proc := parts.process_material as ParticleProcessMaterial
	if proc == null:
		return
	parts.amount = _cap(CAP_ELEMENT)
	parts.lifetime = 0.4
	parts.explosiveness = 0.82
	proc.scale_min = 0.04 * scale
	proc.scale_max = 0.1 * scale
	match shot_vfx:
		FxSurface.SHOT_FIRE:
			proc.color = Color(1.0, 0.4, 0.08)
			proc.direction = Vector3(0, 1, 0)
			proc.spread = 30.0
			proc.initial_velocity_min = 0.6
			proc.initial_velocity_max = 2.4
			proc.gravity = Vector3(0, 2.4, 0)
			_set_draw(parts, "add", proc.color, 6.5, Vector2(0.05, 0.06))
		FxSurface.SHOT_ICE:
			proc.color = Color(0.72, 0.88, 1.0)
			proc.spread = 50.0
			proc.initial_velocity_min = 0.2
			proc.initial_velocity_max = 1.1
			proc.gravity = Vector3(0, 0.15, 0)
			parts.lifetime = 0.7
			_set_draw(parts, "mix", proc.color, 0.8, Vector2(0.1, 0.1))
		_:
			proc.color = Color(0.42, 0.78, 1.0)
			proc.spread = 40.0
			proc.initial_velocity_min = 0.4
			proc.initial_velocity_max = 2.0
			proc.gravity = Vector3.ZERO
			_set_draw(parts, "add", proc.color, 7.0, Vector2(0.06, 0.06))


func _configure_death(parts: GPUParticles3D, surface: String, scale: float, explodes: bool) -> void:
	var proc := parts.process_material as ParticleProcessMaterial
	if proc == null:
		return
	parts.explosiveness = 0.96
	proc.spread = 80.0
	proc.direction = Vector3(0, 1, 0)
	if explodes:
		parts.amount = _cap(CAP_EXPLODE)
		parts.lifetime = 0.65
		proc.initial_velocity_min = 3.5 * scale
		proc.initial_velocity_max = 9.0 * scale
		proc.gravity = Vector3(0, -6.0, 0)
		proc.scale_min = 0.05 * scale
		proc.scale_max = 0.14 * scale
		proc.color = Color(1.0, 0.5, 0.16) if surface == FxSurface.METAL else Color(0.45, 0.55, 1.0)
		_set_draw(parts, "add", proc.color, 8.0, Vector2(0.07, 0.07))
	elif surface == FxSurface.SKELETAL:
		parts.amount = _cap(CAP_DEATH)
		parts.lifetime = 0.5
		proc.initial_velocity_min = 1.6 * scale
		proc.initial_velocity_max = 5.0 * scale
		proc.gravity = Vector3(0, -10.0, 0)
		proc.color = Color(0.86, 0.8, 0.64)
		_set_draw(parts, "mix", proc.color, 0.4, Vector2(0.05, 0.04))
	else:
		parts.amount = _cap(CAP_DEATH)
		parts.lifetime = 0.48
		proc.initial_velocity_min = 1.4 * scale
		proc.initial_velocity_max = 4.4 * scale
		proc.gravity = Vector3(0, -10.0, 0)
		proc.color = Color(0.42, 0.04, 0.04)
		_set_draw(parts, "mix", proc.color, 0.2, Vector2(0.06, 0.07))


func _set_draw(parts: GPUParticles3D, mode: String, color: Color, glow: float, quad_size: Vector2) -> void:
	var key := "%s_%s_%.2f_%.2f" % [mode, color.to_html(false), quad_size.x, glow]
	if not _draw.has(key):
		var mesh := SphereMesh.new()
		mesh.radius = maxf(quad_size.x, quad_size.y) * 0.55
		mesh.height = mesh.radius * 2.0
		mesh.radial_segments = 8
		mesh.rings = 4
		mesh.material = _particle_mat(mode, color, glow)
		_draw[key] = mesh
	parts.draw_pass_1 = _draw[key]


func _particle_mat(mode: String, color: Color, glow: float) -> Material:
	var path := SHADER_ADD if mode == "add" else SHADER_MIX
	if ResourceLoader.exists(path) and RenderingServer.get_current_rendering_method() == "forward_plus":
		var sh := ShaderMaterial.new()
		sh.shader = load(path)
		sh.set_shader_parameter("tint", color)
		sh.set_shader_parameter("glow", glow)
		return sh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if mode == "add" else BaseMaterial3D.BLEND_MODE_MIX
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = maxf(0.4, glow * 0.45)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	return mat


func _style_bolt(bolt: Node3D, shot_vfx: String) -> void:
	var core := bolt.get_node_or_null("Core") as MeshInstance3D
	var light := bolt.get_node_or_null("Glow") as OmniLight3D
	var trail := bolt.get_node_or_null("Trail") as GPUParticles3D
	var col := FxSurface.shot_color(shot_vfx)
	if core:
		core.material_override = PbrLibrary.emissive(col, 10.0)
		var mesh := core.mesh as SphereMesh
		if mesh:
			var r := 0.09
			if shot_vfx == FxSurface.SHOT_ICE:
				r = 0.12
			mesh.radius = r
			mesh.height = r * 2.0
	if light:
		light.light_color = col
		light.light_energy = 3.6
		light.omni_range = 2.8
	if trail:
		trail.amount = _cap(CAP_TRAIL)
		trail.emitting = false
		var proc := trail.process_material as ParticleProcessMaterial
		if proc:
			proc.color = col
			proc.direction = Vector3(0, 0, 1)
			if shot_vfx == FxSurface.SHOT_ICE:
				proc.gravity = Vector3(0, 0.2, 0)
				proc.initial_velocity_min = 0.05
				proc.initial_velocity_max = 0.25
				_set_draw(trail, "mix", col, 1.2, Vector2(0.08, 0.08))
			elif shot_vfx == FxSurface.SHOT_FIRE:
				proc.gravity = Vector3(0, 1.4, 0)
				_set_draw(trail, "add", col, 5.0, Vector2(0.05, 0.05))
			else:
				proc.gravity = Vector3.ZERO
				_set_draw(trail, "add", col, 6.0, Vector2(0.05, 0.05))


func _make_emitters(count: int, prefix: String, amount: int, life: float, mode: String, color: Color, glow: float, local_coords: bool) -> Array:
	var out: Array = []
	for i in count:
		var parts := GPUParticles3D.new()
		parts.name = "%s_%d" % [prefix, i]
		parts.one_shot = true
		parts.amount = _cap(amount)
		parts.lifetime = life
		parts.explosiveness = 0.92
		parts.local_coords = local_coords
		parts.emitting = false
		parts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parts.visibility_aabb = AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))
		var proc := ParticleProcessMaterial.new()
		proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		proc.emission_sphere_radius = 0.04
		proc.direction = Vector3(0, 0, -1)
		proc.spread = 40.0
		proc.initial_velocity_min = 1.2
		proc.initial_velocity_max = 4.0
		proc.gravity = Vector3(0, -8.0, 0)
		proc.scale_min = 0.04
		proc.scale_max = 0.09
		proc.color = color
		parts.process_material = proc
		_set_draw(parts, mode, color, glow, Vector2(0.06, 0.06))
		parts.visible = false
		parts.position = Vector3(0.0, -90.0, 0.0)
		if prefix == "muzzle":
			var core := MeshInstance3D.new()
			core.name = "FlashCore"
			var sphere := SphereMesh.new()
			sphere.radius = 0.16
			sphere.height = 0.32
			sphere.radial_segments = 12
			sphere.rings = 6
			core.mesh = sphere
			var cmat := StandardMaterial3D.new()
			cmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			cmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			cmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			cmat.albedo_color = Color(1.0, 0.78, 0.32, 1.0)
			cmat.emission_enabled = true
			cmat.emission = Color(1.0, 0.72, 0.28)
			cmat.emission_energy_multiplier = 14.0
			cmat.cull_mode = BaseMaterial3D.CULL_DISABLED
			cmat.no_depth_test = true
			core.material_override = cmat
			core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			core.visible = false
			parts.add_child(core)
		add_child(parts)
		out.append(parts)
	return out


func _make_tracers(count: int) -> Array:
	var out: Array = []
	var shader: Shader = load(SHADER_TRACER) if ResourceLoader.exists(SHADER_TRACER) else null
	var use_shader := shader != null and RenderingServer.get_current_rendering_method() == "forward_plus"
	for i in count:
		var mi := MeshInstance3D.new()
		mi.name = "Tracer_%d" % i
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.045, 0.045, 1.0)
		mi.mesh = mesh
		if use_shader:
			var mat := ShaderMaterial.new()
			mat.shader = shader
			mat.set_shader_parameter("tint", Color(1.0, 0.8, 0.35, 1.0))
			mat.set_shader_parameter("fade", 1.0)
			mi.material_override = mat
		else:
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			mat.albedo_color = Color(1.0, 0.84, 0.42, 1.0)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.82, 0.38)
			mat.emission_energy_multiplier = 12.0
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.no_depth_test = true
			mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		mi.position = Vector3(0.0, -90.0, 0.0)
		add_child(mi)
		out.append(mi)
	return out


func _make_lights(count: int) -> Array:
	var out: Array = []
	for i in count:
		var light := OmniLight3D.new()
		light.name = "FxLight_%d" % i
		light.shadow_enabled = false
		light.light_energy = 0.0
		light.omni_range = 2.0
		light.omni_attenuation = 1.6
		light.visible = false
		light.position = Vector3(0.0, -90.0, 0.0)
		add_child(light)
		out.append(light)
	return out


func _make_decals(count: int) -> Array:
	var out: Array = []
	for i in count:
		var decal := Decal.new()
		decal.name = "FxDecal_%d" % i
		decal.visible = false
		decal.upper_fade = 0.4
		decal.lower_fade = 0.4
		decal.position = Vector3(0.0, -90.0, 0.0)
		add_child(decal)
		out.append(decal)
	return out


func _make_corpses(count: int) -> Array:
	var out: Array = []
	for i in count:
		var holder := Node3D.new()
		holder.name = "Corpse_%d" % i
		holder.visible = false
		holder.position = Vector3(0.0, -90.0, 0.0)
		add_child(holder)
		out.append(holder)
	return out


func _make_bolts(count: int) -> Array:
	var out: Array = []
	for i in count:
		var bolt := Node3D.new()
		bolt.name = "Bolt_%d" % i
		var core := Greybox.sphere(0.1, PbrLibrary.emissive(Color(0.55, 0.78, 1.0), 9.0), "Core")
		bolt.add_child(core)
		var light := OmniLight3D.new()
		light.name = "Glow"
		light.shadow_enabled = false
		light.omni_range = 2.6
		light.light_energy = 3.2
		bolt.add_child(light)
		var trail := GPUParticles3D.new()
		trail.name = "Trail"
		trail.amount = _cap(CAP_TRAIL)
		trail.lifetime = 0.28
		trail.local_coords = true
		trail.emitting = false
		trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var proc := ParticleProcessMaterial.new()
		proc.direction = Vector3(0, 0, 1)
		proc.spread = 12.0
		proc.initial_velocity_min = 0.1
		proc.initial_velocity_max = 0.4
		proc.gravity = Vector3.ZERO
		proc.scale_min = 0.04
		proc.scale_max = 0.09
		proc.color = Color(0.5, 0.8, 1.0)
		trail.process_material = proc
		_set_draw(trail, "add", proc.color, 5.0, Vector2(0.05, 0.05))
		bolt.add_child(trail)
		bolt.visible = false
		bolt.position = Vector3(0.0, -90.0, 0.0)
		add_child(bolt)
		out.append(bolt)
	return out


func _make_flash_mats(count: int) -> Array:
	var out: Array = []
	var shader: Shader = load(SHADER_FLASH) if ResourceLoader.exists(SHADER_FLASH) else null
	var use_shader := shader != null and RenderingServer.get_current_rendering_method() == "forward_plus"
	for i in count:
		if use_shader:
			var mat := ShaderMaterial.new()
			mat.shader = shader
			mat.set_shader_parameter("tint", Color(1.0, 0.86, 0.7, 1.0))
			mat.set_shader_parameter("intensity", 0.0)
			out.append(mat)
		else:
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			mat.albedo_color = Color(1.0, 0.92, 0.78, 0.85)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.9, 0.72)
			mat.emission_energy_multiplier = 10.0
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			out.append(mat)
	return out


func _make_splatter(color: Color, blobs: int) -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(color.r * 90.0 + color.g * 40.0 + blobs)
	for _b in blobs:
		var cx := rng.randi_range(10, 54)
		var cz := rng.randi_range(10, 54)
		var rad := rng.randi_range(3, 11)
		for y in range(maxi(0, cz - rad), mini(64, cz + rad)):
			for x in range(maxi(0, cx - rad), mini(64, cx + rad)):
				var dx := float(x - cx)
				var dy := float(y - cz)
				var d := sqrt(dx * dx + dy * dy) / float(rad)
				if d < 1.0:
					var a := (1.0 - d) * color.a * rng.randf_range(0.45, 1.0)
					var prev := img.get_pixel(x, y)
					img.set_pixel(x, y, Color(color.r, color.g, color.b, minf(1.0, prev.a + a)))
	var tex := ImageTexture.create_from_image(img)
	return tex


func _cap(base: int) -> int:
	var q := 1.0
	if GameSettings:
		match GameSettings.quality:
			GameSettings.Quality.LOW:
				q = 0.5
			GameSettings.Quality.MEDIUM:
				q = 0.72
			GameSettings.Quality.ULTRA:
				q = 1.0
			_:
				q = 0.9
	return clampi(int(round(float(base) * q)), 4, base)


func _warm_emit() -> void:
	var ghost := Vector3(0.0, -80.0, 0.0)
	play_muzzle(ghost, Color(1.0, 0.7, 0.3), FxSurface.SHOT_KINETIC)
	play_muzzle(ghost, Color(1.0, 0.4, 0.1), FxSurface.SHOT_FIRE)
	play_tracer(ghost, ghost + Vector3(0, 0, -2), Color(1.0, 0.8, 0.3), FxSurface.SHOT_KINETIC)
	play_impact(ghost, Vector3.UP, FxSurface.METAL, Color(1, 0.7, 0.3), 1.0)
	play_impact(ghost, Vector3.UP, FxSurface.ORGANIC, Color(0.5, 0.05, 0.05), 1.0)
	play_impact(ghost, Vector3.UP, FxSurface.SKELETAL, Color(0.8, 0.75, 0.6), 1.0)
	play_impact(ghost, Vector3.UP, FxSurface.TERRAIN, Color(0.7, 0.55, 0.3), 1.0)
	play_element(ghost, FxSurface.SHOT_FIRE, 1.0)
	play_element(ghost, FxSurface.SHOT_ICE, 1.0)
	play_element(ghost, FxSurface.SHOT_SPELL, 1.0)
	for rec in _active:
		if str(rec.get("bucket", "")) != "corpse":
			rec.life = 0.0
	_tick(0.02)
