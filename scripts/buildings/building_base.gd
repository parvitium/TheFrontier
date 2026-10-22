class_name BuildingBase
extends StaticBody3D

var building_id: String = ""
var serial: int = -1
var grid_origin: Vector2i = Vector2i.ZERO


func setup(def: BuildingDef, origin: Vector2i, p_serial: int) -> void:
	building_id = def.id
	serial = p_serial
	grid_origin = origin
	set_meta("grid_origin", origin)
	set_meta("building_serial", p_serial)
	add_to_group("buildings")
	add_to_group("damageable")
	collision_layer = 8
	collision_mask = 0
	var size := Vector3(float(def.footprint.x) * 1.7, 1.8, float(def.footprint.y) * 1.7)
	position = PlacementRules.cell_to_world(origin, 0.0) + Vector3((def.footprint.x - 1) * PlacementRules.CELL_SIZE * 0.5, 0, (def.footprint.y - 1) * PlacementRules.CELL_SIZE * 0.5)
	var visual := Node3D.new()
	visual.name = "Visual"
	visual.set_meta("asset_slot", "building_%s" % def.id)
	add_child(visual)
	_build_visual(visual, def, size)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.position.y = size.y * 0.5
	add_child(col)
	var health := Health.new()
	health.name = "Health"
	health.configure(def.max_health, "building")
	health.died.connect(_on_died)
	add_child(health)


func _build_visual(visual: Node3D, def: BuildingDef, size: Vector3) -> void:
	var mesh := Greybox.box(size, Greybox.material(def.color, def.color, 0.25, 0.15, 0.55), "Hull")
	mesh.position.y = size.y * 0.5
	visual.add_child(mesh)


func dismantle() -> void:
	queue_free()


func _on_died(_source: Node) -> void:
	Session.cmd_building_destroyed(serial)
	queue_free()
