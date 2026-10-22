class_name BuilderController
extends Node3D

var catalog: Array[BuildingDef] = []
var index: int = 0
var active: bool = false
var last_reason: String = ""
var _ghost: MeshInstance3D
var _origin: Vector2i = Vector2i.ZERO
var _valid: bool = false


func _ready() -> void:
	catalog = BuildingCatalog.available_for_mode(Session.mode)
	_ghost = Greybox.box(Vector3(1.8, 1.6, 1.8), _ghost_mat(false), "Ghost")
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ghost)
	_ghost.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed("cycle_build_next"):
		_cycle(1)
	elif event.is_action_pressed("cycle_build_prev"):
		_cycle(-1)
	elif event.is_action_pressed("build_1"):
		_select(0)
	elif event.is_action_pressed("build_2"):
		_select(1)
	elif event.is_action_pressed("build_3"):
		_select(2)
	elif event.is_action_pressed("build_4"):
		_select(3)
	elif event.is_action_pressed("build_5"):
		_select(4)


func set_active(on: bool) -> void:
	active = on
	_ghost.visible = on
	if on:
		catalog = BuildingCatalog.available_for_mode(Session.mode)
		index = clampi(index, 0, max(0, catalog.size() - 1))


func current() -> BuildingDef:
	if catalog.is_empty():
		return null
	return catalog[index]


func update_ghost(camera: Camera3D) -> void:
	if not active or current() == null:
		_ghost.visible = false
		return
	var from := camera.global_position
	var forward := -camera.global_transform.basis.z
	var to := from + forward * 22.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	var point := Vector3.ZERO
	if not hit.is_empty():
		point = hit.position
	elif forward.y < -0.02:
		var t: float = from.y / -forward.y
		if t <= 0.0 or t > 28.0:
			_valid = false
			last_reason = "Aim at the ground."
			_ghost.visible = false
			return
		point = from + forward * t
	else:
		var flat := Vector3(forward.x, 0.0, forward.z)
		if flat.length() < 0.05:
			_valid = false
			last_reason = "Aim at the ground."
			_ghost.visible = false
			return
		point = from + flat.normalized() * 6.0
		point.y = 0.0
	_origin = PlacementRules.world_to_cell(point)
	var world := PlacementRules.cell_to_world(_origin, 0.0)
	var def := current()
	var size := Vector3(float(def.footprint.x) * 1.85, 1.6, float(def.footprint.y) * 1.85)
	(_ghost.mesh as BoxMesh).size = size
	_ghost.global_position = world + Vector3((def.footprint.x - 1) * PlacementRules.CELL_SIZE * 0.5, size.y * 0.5, (def.footprint.y - 1) * PlacementRules.CELL_SIZE * 0.5)
	var placement := PlacementRules.evaluate(Session.state.occupied_cells, def.id, _origin)
	var afford := Economy.can_afford(Session.state.resources, def.cost())
	_valid = placement.ok and afford
	if not placement.ok:
		last_reason = placement.reason
	elif not afford:
		last_reason = "Need %d scrap, %d crystal." % [def.scrap_cost, def.crystal_cost]
	else:
		last_reason = "LMB place · %s" % def.display_name
	_ghost.material_override = _ghost_mat(_valid)
	_ghost.visible = true


func try_place() -> void:
	if not active or current() == null or not _valid:
		return
	var result := Session.cmd_try_place(current().id, _origin)
	if result.ok:
		var arena := _arena()
		if arena:
			BuildingFactory.spawn(arena, current().id, _origin, int(result.serial))
		Sfx.play("place_build", 0.95)
		last_reason = "Placed %s." % current().display_name
	else:
		last_reason = result.reason


func try_dismantle(camera: Camera3D) -> void:
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * 10.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 8
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var collider := hit.collider as Node
	if collider == null or not collider.has_meta("grid_origin"):
		return
	var origin: Vector2i = collider.get_meta("grid_origin")
	var result := Session.cmd_dismantle_at(origin)
	if result.ok and collider.has_method("dismantle"):
		collider.dismantle()
	elif result.ok:
		collider.queue_free()


func status_text() -> String:
	var def := current()
	if def == null:
		return ""
	return "[BUILD] %s  %d scrap / %d crystal — %s" % [def.display_name, def.scrap_cost, def.crystal_cost, last_reason]


func _cycle(step: int) -> void:
	if catalog.is_empty():
		return
	index = posmod(index + step, catalog.size())


func _select(i: int) -> void:
	if i >= 0 and i < catalog.size():
		index = i


func _arena() -> Arena:
	var node: Node = self
	while node:
		if node is Arena:
			return node
		node = node.get_parent()
	return get_tree().current_scene as Arena


func _ghost_mat(ok: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.25, 0.9, 0.45, 0.38) if ok else Color(0.9, 0.2, 0.18, 0.38)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat
