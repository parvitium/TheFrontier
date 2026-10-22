class_name EscapeShip
extends BuildingBase


func _build_visual(visual: Node3D, def: BuildingDef, _size: Vector3) -> void:
	var hull := Greybox.box(Vector3(3.2, 1.1, 2.0), Greybox.material(def.color, Color(1.0, 0.8, 0.2), 0.8, 0.35, 0.35), "Hull")
	hull.position.y = 0.9
	visual.add_child(hull)
	var nose := Greybox.box(Vector3(1.1, 0.7, 1.2), Greybox.material(def.color.lightened(0.15), Color(1.0, 0.85, 0.3), 1.2, 0.3, 0.3), "Nose")
	nose.position = Vector3(1.8, 0.9, 0)
	visual.add_child(nose)
	var fin := Greybox.box(Vector3(0.15, 1.4, 0.8), Greybox.material(Color(0.3, 0.32, 0.36), Color.BLACK, 0.0, 0.2, 0.5), "Fin")
	fin.position = Vector3(-1.2, 1.5, 0)
	visual.add_child(fin)
