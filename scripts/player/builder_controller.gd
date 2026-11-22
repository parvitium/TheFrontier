class_name BuilderController
extends Node3D

var catalog: Array[BuildingDef] = []
var index: int = 0
var active: bool = false
var last_reason: String = ""
var selected_serial: int = -1
var sell_hold: float = 0.0
var _ghost: MeshInstance3D
var _origin: Vector2i = Vector2i.ZERO
var _valid: bool = false
var _aimed_serial: int = -1


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
	_ghost.visible = on and selected_serial < 0
	if on:
		catalog = BuildingCatalog.available_for_mode(Session.mode)
		index = clampi(index, 0, max(0, catalog.size() - 1))
	else:
		clear_selection()
		sell_hold = 0.0


func current() -> BuildingDef:
	if catalog.is_empty():
		return null
	return catalog[index]


func update_ghost(camera: Camera3D) -> void:
	_aimed_serial = _building_under_aim(camera)
	if selected_serial >= 0:
		_ghost.visible = false
		return
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
		point.y = Landscape.height_at(point.x, point.z)
	_origin = PlacementRules.world_to_cell(point)
	var def := current()
	var size := Vector3(float(def.footprint.x) * 1.85, 1.6, float(def.footprint.y) * 1.85)
	(_ghost.mesh as BoxMesh).size = size
	var seated := PlacementRules.seat_origin(def.id, _origin)
	var basis := PlacementRules.foundation_basis(seated.x, seated.z)
	_ghost.global_transform = Transform3D(basis, seated + basis.y * (size.y * 0.5))
	var placement := PlacementRules.evaluate(Session.state.occupied_cells, def.id, _origin)
	var afford := Economy.can_afford(Session.state.resources, def.cost())
	_valid = placement.ok and afford
	if not placement.ok:
		last_reason = placement.reason
	elif not afford:
		last_reason = "Need %d scrap, %d crystal." % [def.scrap_cost, def.crystal_cost]
	else:
		last_reason = "LMB place · RMB cancel · %s" % def.display_name
	if _aimed_serial >= 0:
		last_reason = "LMB inspect · RMB cancel"
	_ghost.material_override = _ghost_mat(_valid)
	_ghost.visible = true


func try_place() -> void:
	if selected_serial >= 0:
		return
	if _aimed_serial >= 0:
		select_serial(_aimed_serial)
		return
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


func cancel_placement() -> void:
	sell_hold = 0.0
	if selected_serial >= 0:
		clear_selection()
		last_reason = "Closed."
		return
	last_reason = "Placement cancelled."


func select_serial(serial: int) -> void:
	if serial < 0 or not Session.state.building_instances.has(serial):
		return
	selected_serial = serial
	sell_hold = 0.0
	_ghost.visible = false
	last_reason = "Inspecting."


func clear_selection() -> void:
	selected_serial = -1
	sell_hold = 0.0


func tick_sell_hold(delta: float, holding: bool) -> bool:
	if selected_serial < 0:
		sell_hold = 0.0
		return false
	if not holding:
		sell_hold = 0.0
		return false
	sell_hold += delta
	if sell_hold >= BuildingValue.SELL_HOLD:
		sell_hold = 0.0
		return confirm_sell()
	return false


func confirm_sell() -> bool:
	if selected_serial < 0:
		return false
	var origin := _origin_of_serial(selected_serial)
	var result := Session.cmd_dismantle_at(origin)
	clear_selection()
	if result.ok:
		last_reason = "Sold · refund %s" % BuildingValue.refund_text(result.refund)
		return true
	last_reason = str(result.get("reason", "Cannot sell."))
	return false


func try_upgrade() -> bool:
	if selected_serial < 0:
		return false
	var result := Session.cmd_upgrade_building(selected_serial)
	if result.ok:
		last_reason = "Upgraded to %s." % TurretUpgrades.label_for(int(result.tier))
		return true
	last_reason = str(result.get("reason", "Cannot upgrade."))
	return false


func aimed_serial() -> int:
	return _aimed_serial


func status_text() -> String:
	if selected_serial >= 0:
		var hold := ""
		if sell_hold > 0.0:
			hold = "  selling %.0f%%" % (clampf(sell_hold / BuildingValue.SELL_HOLD, 0.0, 1.0) * 100.0)
		return "[INSPECT] Hold X to sell · RMB close%s" % hold
	var def := current()
	if def == null:
		return ""
	return "[BUILD] %s  %d scrap / %d crystal — %s" % [def.display_name, def.scrap_cost, def.crystal_cost, last_reason]


func _building_under_aim(camera: Camera3D) -> int:
	if camera == null:
		return -1
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * 12.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 8
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return -1
	var collider := hit.collider as Node
	if collider == null:
		return -1
	if collider.has_meta("building_serial"):
		return int(collider.get_meta("building_serial"))
	if collider is BuildingBase:
		return (collider as BuildingBase).serial
	return -1


func _origin_of_serial(serial: int) -> Vector2i:
	if not Session.state.building_instances.has(serial):
		return Vector2i.ZERO
	var info: Dictionary = Session.state.building_instances[serial]
	var cells: Array = info.get("cells", [])
	if cells.is_empty():
		return Vector2i.ZERO
	return cells[0] as Vector2i


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
