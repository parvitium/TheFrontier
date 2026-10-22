class_name ResourceNode
extends StaticBody3D

var resource_type: String = Ids.SCRAP
var remaining: int = 12
var gather_interval: float = 0.45
var respawn_amount: int = 8
var _progress: float = 0.0


func configure(p_type: String, amount: int, interval: float, color: Color, emission: Color) -> void:
	resource_type = p_type
	remaining = amount
	respawn_amount = amount
	gather_interval = interval
	add_to_group("resource_nodes")
	add_to_group("interactable")
	collision_layer = 64
	collision_mask = 0
	set_meta("resource_type", resource_type)
	var visual := Node3D.new()
	visual.name = "Visual"
	visual.set_meta("asset_slot", "resource_%s" % resource_type)
	var slot := "resource_crystal" if resource_type == Ids.CRYSTAL else "resource_scrap"
	if VisualKit.fill(visual, slot) == null:
		if resource_type == Ids.CRYSTAL:
			visual.add_child(Greybox.cylinder(0.35, 1.4, PbrLibrary.emissive(emission, 5.0), "Crystal"))
			visual.get_child(0).position.y = 0.7
		else:
			visual.add_child(Greybox.box(Vector3(1.1, 0.7, 0.9), PbrLibrary.rust(color), "Scrap"))
			visual.get_child(0).position.y = 0.35
	add_child(visual)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.2, 1.2, 1.2)
	col.shape = shape
	col.position.y = 0.6
	add_child(col)


func gather(delta: float) -> int:
	if remaining <= 0:
		return 0
	_progress += delta
	if _progress < gather_interval:
		return 0
	_progress = 0.0
	remaining -= 1
	_update_visual()
	return 1


func restock() -> void:
	remaining = respawn_amount
	_progress = 0.0
	_update_visual()
	visible = true


func _update_visual() -> void:
	var visual := get_node_or_null("Visual") as Node3D
	if visual:
		visual.scale = Vector3.ONE * (0.35 + 0.65 * (float(remaining) / float(maxi(1, respawn_amount))))
	var depleted := remaining <= 0
	visible = not depleted
	collision_layer = 0 if depleted else 64
