class_name CombatFx
extends Node

var _life: float = 0.12
var _kind: String = "tracer"


static func muzzle_flash(parent: Node3D, at: Vector3, color: Color = Color(1.0, 0.78, 0.35)) -> void:
	if parent == null:
		return
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 5.5
	light.omni_range = 3.6
	light.omni_attenuation = 1.6
	light.position = parent.to_local(at) if parent.is_inside_tree() else at
	parent.add_child(light)
	var blob := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.045
	sphere.height = 0.09
	sphere.radial_segments = 10
	sphere.rings = 6
	blob.mesh = sphere
	blob.material_override = PbrLibrary.emissive(color, 12.0)
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blob.position = light.position
	parent.add_child(blob)
	_fade_free(light, 0.07)
	_fade_free(blob, 0.08)


static func tracer(host: Node, from: Vector3, to: Vector3, color: Color = Color(1.0, 0.82, 0.35)) -> void:
	if host == null:
		return
	var fx := CombatFx.new()
	fx._kind = "tracer"
	fx._life = 0.09
	host.add_child(fx)
	var mi := MeshInstance3D.new()
	var mesh := ImmediateMesh.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 8.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx.add_child(mi)
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, mat)
	var dir := to - from
	var len := dir.length()
	if len < 0.05:
		fx.queue_free()
		return
	dir /= len
	var up := Vector3.UP
	if absf(dir.dot(up)) > 0.95:
		up = Vector3.RIGHT
	var side := dir.cross(up).normalized() * 0.012
	var top := dir.cross(side).normalized() * 0.012
	_quad(mesh, from, to, side)
	_quad(mesh, from, to, top)
	mesh.surface_end()


static func impact(host: Node, at: Vector3, color: Color = Color(1.0, 0.7, 0.3)) -> void:
	if host == null:
		return
	var fx := CombatFx.new()
	fx._kind = "impact"
	fx._life = 0.28
	fx.global_position = at
	host.add_child(fx)
	var parts := GPUParticles3D.new()
	parts.emitting = true
	parts.one_shot = true
	parts.amount = 14
	parts.lifetime = 0.28
	parts.explosiveness = 0.92
	parts.local_coords = false
	var proc := ParticleProcessMaterial.new()
	proc.direction = Vector3(0, 1, 0)
	proc.spread = 50.0
	proc.initial_velocity_min = 1.6
	proc.initial_velocity_max = 4.2
	proc.gravity = Vector3(0, -8.0, 0)
	proc.scale_min = 0.04
	proc.scale_max = 0.09
	proc.color = color
	parts.process_material = proc
	var draw := SphereMesh.new()
	draw.radius = 0.04
	draw.height = 0.08
	draw.radial_segments = 8
	draw.rings = 4
	var mat := PbrLibrary.emissive(color, 7.0)
	draw.material = mat
	parts.draw_pass_1 = draw
	fx.add_child(parts)
	var spark := OmniLight3D.new()
	spark.light_color = color
	spark.light_energy = 2.8
	spark.omni_range = 2.2
	fx.add_child(spark)


static func _quad(mesh: ImmediateMesh, from: Vector3, to: Vector3, offset: Vector3) -> void:
	mesh.surface_add_vertex(from - offset)
	mesh.surface_add_vertex(from + offset)
	mesh.surface_add_vertex(to + offset)
	mesh.surface_add_vertex(from - offset)
	mesh.surface_add_vertex(to + offset)
	mesh.surface_add_vertex(to - offset)


static func _fade_free(node: Node, life: float) -> void:
	var fx := CombatFx.new()
	fx._kind = "fade"
	fx._life = life
	node.add_child(fx)


func _process(delta: float) -> void:
	_life -= delta
	if _kind == "tracer":
		var mi := get_child(0) as MeshInstance3D if get_child_count() > 0 else null
		if mi and mi.material_override is StandardMaterial3D:
			var mat := mi.material_override as StandardMaterial3D
			mat.albedo_color.a = clampf(_life / 0.09, 0.0, 1.0)
	if _life <= 0.0:
		if get_parent() and get_parent() is OmniLight3D:
			get_parent().queue_free()
		elif get_parent() and get_parent() is MeshInstance3D and _kind != "tracer" and _kind != "impact":
			get_parent().queue_free()
		else:
			queue_free()
