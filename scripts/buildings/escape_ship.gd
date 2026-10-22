class_name EscapeShip
extends BuildingBase


func _build_visual(visual: Node3D, def: BuildingDef, _size: Vector3) -> void:
	if VisualKit.fill(visual, "building_escape_ship") != null:
		return
	var hull := Greybox.box(Vector3(3.2, 1.1, 2.0), PbrLibrary.metal(def.color, 0.55, 0.7), "Hull")
	hull.position.y = 0.9
	visual.add_child(hull)
	var nose := Greybox.box(Vector3(1.1, 0.7, 1.2), PbrLibrary.metal(def.color.lightened(0.15), 0.5, 0.65), "Nose")
	nose.position = Vector3(1.8, 0.9, 0)
	visual.add_child(nose)
	var fin := Greybox.box(Vector3(0.15, 1.4, 0.8), PbrLibrary.metal(Color(0.3, 0.32, 0.36)), "Fin")
	fin.position = Vector3(-1.2, 1.5, 0)
	visual.add_child(fin)
