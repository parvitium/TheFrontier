class_name WallBuilding
extends BuildingBase


func _build_visual(visual: Node3D, def: BuildingDef, size: Vector3) -> void:
	if VisualKit.fill(visual, "building_wall") != null:
		return
	var mesh := Greybox.box(Vector3(size.x, 2.2, size.z), PbrLibrary.concrete(def.color), "Wall")
	mesh.position.y = 1.1
	visual.add_child(mesh)
