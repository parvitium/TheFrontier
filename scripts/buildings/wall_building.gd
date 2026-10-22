class_name WallBuilding
extends BuildingBase


func _build_visual(visual: Node3D, def: BuildingDef, size: Vector3) -> void:
	var mesh := Greybox.box(Vector3(size.x, 2.2, size.z), Greybox.material(def.color, Color.BLACK, 0.0, 0.08, 0.7), "Wall")
	mesh.position.y = 1.1
	visual.add_child(mesh)
