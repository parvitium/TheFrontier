class_name Relic
extends StaticBody3D


func _ready() -> void:
	add_to_group("relics")
	add_to_group("interactable")
	collision_layer = 64
	collision_mask = 0
	var visual := Node3D.new()
	visual.name = "Visual"
	visual.set_meta("asset_slot", "signal_relic")
	var body := Greybox.box(Vector3(0.7, 0.7, 0.7), Greybox.material(Color(0.95, 0.82, 0.28), Color(1.0, 0.85, 0.3), 2.8, 0.4, 0.25), "Relic")
	body.position.y = 0.7
	visual.add_child(body)
	add_child(visual)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.8, 1.2, 0.8)
	col.shape = shape
	col.position.y = 0.6
	add_child(col)
	var light := OmniLight3D.new()
	light.omni_range = 6.0
	light.light_color = Color(1.0, 0.86, 0.4)
	light.light_energy = 1.6
	light.position.y = 1.2
	add_child(light)


func _process(delta: float) -> void:
	rotate_y(delta * 1.2)
	var visual := get_node_or_null("Visual") as Node3D
	if visual:
		visual.position.y = 0.15 + sin(Time.get_ticks_msec() * 0.003) * 0.12


func collect() -> void:
	Session.cmd_collect_relic()
	queue_free()
