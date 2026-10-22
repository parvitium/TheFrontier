class_name TrapBuilding
extends BuildingBase

const DPS := 8.0
const SLOW := 0.5

var _area: Area3D


func _build_visual(visual: Node3D, def: BuildingDef, _size: Vector3) -> void:
	if VisualKit.fill(visual, "building_trap") == null:
		var pad := Greybox.box(Vector3(1.8, 0.12, 1.8), PbrLibrary.metal(def.color, 0.4, 0.8), "Pad")
		pad.position.y = 0.06
		visual.add_child(pad)
	_area = Area3D.new()
	_area.collision_layer = 0
	_area.collision_mask = 4
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.9, 1.2, 1.9)
	col.shape = shape
	col.position.y = 0.5
	_area.add_child(col)
	add_child(_area)


func _physics_process(delta: float) -> void:
	if _area == null or not Session.state.is_running():
		return
	for body in _area.get_overlapping_bodies():
		if body.is_in_group("mobs") and body.has_method("apply_slow"):
			body.apply_slow(SLOW, 0.35)
			Session.cmd_trap_pulse(serial, body, delta, DPS)
