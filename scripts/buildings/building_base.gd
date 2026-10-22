class_name BuildingBase
extends StaticBody3D

var building_id: String = ""
var serial: int = -1
var grid_origin: Vector2i = Vector2i.ZERO


static func footprint_collider_size(footprint: Vector2i, height: float = 1.8) -> Vector3:
	return Vector3(
		float(footprint.x) * PlacementRules.CELL_SIZE,
		height,
		float(footprint.y) * PlacementRules.CELL_SIZE
	)


static func uses_blocking_collider(def: BuildingDef) -> bool:
	return def != null and def.blocks_navigation


func setup(def: BuildingDef, origin: Vector2i, p_serial: int) -> void:
	building_id = def.id
	serial = p_serial
	grid_origin = origin
	set_meta("grid_origin", origin)
	set_meta("building_serial", p_serial)
	add_to_group("buildings")
	add_to_group("damageable")
	collision_mask = 0
	var size := footprint_collider_size(def.footprint)
	position = PlacementRules.cell_to_world(origin, 0.0) + Vector3((def.footprint.x - 1) * PlacementRules.CELL_SIZE * 0.5, 0, (def.footprint.y - 1) * PlacementRules.CELL_SIZE * 0.5)
	var visual := Node3D.new()
	visual.name = "Visual"
	visual.set_meta("asset_slot", "building_%s" % def.id)
	add_child(visual)
	_build_visual(visual, def, size)
	# Traps occupy a cell for placement but must not be 1.8 m physics / hitscan walls.
	if uses_blocking_collider(def):
		collision_layer = 8
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		col.position.y = size.y * 0.5
		add_child(col)
	else:
		collision_layer = 0
	var health := Health.new()
	health.name = "Health"
	health.configure(def.max_health, "building")
	add_child(health)
	GameBus.building_health_changed.connect(_sync_health)
	GameBus.building_destroyed.connect(_on_session_destroyed)
	_sync_health(serial, float(Session.state.building_hp.get(serial, def.max_health)), def.max_health)


func _build_visual(visual: Node3D, def: BuildingDef, size: Vector3) -> void:
	if VisualKit.fill(visual, "building_%s" % def.id) != null:
		return
	var mesh := Greybox.box(size, PbrLibrary.metal(def.color, 0.35, 0.9), "Hull")
	mesh.position.y = size.y * 0.5
	visual.add_child(mesh)


func dismantle() -> void:
	queue_free()


func _sync_health(p_serial: int, current: float, maximum: float) -> void:
	if p_serial != serial:
		return
	var health := get_node_or_null("Health") as Health
	if health:
		health.max_health = maximum
		health.current = current
		health.dead = current <= 0.0


func _on_session_destroyed(_building_id: String, p_serial: int = -1) -> void:
	if p_serial == serial:
		queue_free()
