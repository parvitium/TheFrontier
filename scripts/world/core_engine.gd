class_name CoreEngine
extends StaticBody3D


func _ready() -> void:
	add_to_group("core")
	add_to_group("damageable")
	collision_layer = 32
	collision_mask = 0
	var visual := Node3D.new()
	visual.name = "Visual"
	visual.set_meta("asset_slot", "core_engine")
	var pedestal := Greybox.cylinder(1.6, 1.1, Greybox.material(Color(0.22, 0.26, 0.3), Color.BLACK, 0.0, 0.35, 0.4), "Pedestal")
	pedestal.position.y = 0.55
	visual.add_child(pedestal)
	var coil := Greybox.cylinder(0.45, 2.2, Greybox.material(Color(0.18, 0.55, 0.58), Color(0.2, 0.9, 0.85), 1.4, 0.6, 0.25), "Coil")
	coil.position.y = 1.9
	visual.add_child(coil)
	var heart := Greybox.sphere(0.7, Greybox.material(Color(0.95, 0.72, 0.2), Color(1.0, 0.7, 0.15), 3.5, 0.1, 0.2), "Heart")
	heart.position.y = 3.1
	heart.name = "Heart"
	visual.add_child(heart)
	add_child(visual)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.6
	shape.height = 3.2
	col.shape = shape
	col.position.y = 1.6
	add_child(col)
	var light := OmniLight3D.new()
	light.omni_range = 16.0
	light.light_color = Color(1.0, 0.78, 0.35)
	light.light_energy = 2.2
	light.position.y = 3.1
	add_child(light)
	var health := Health.new()
	health.name = "Health"
	health.configure(Session.state.core_max_health, "core")
	add_child(health)
	GameBus.core_health_changed.connect(_sync_health)


func _process(delta: float) -> void:
	var heart := get_node_or_null("Visual/Heart") as Node3D
	if heart:
		heart.rotate_y(delta * 0.8)
	var ratio := 1.0
	if Session.state.core_max_health > 0.0:
		ratio = Session.state.core_health / Session.state.core_max_health
	var light := get_node_or_null("OmniLight3D") as OmniLight3D
	if light:
		light.light_energy = 1.0 + 2.2 * ratio


func _sync_health(current: float, maximum: float) -> void:
	var health := get_node_or_null("Health") as Health
	if health:
		health.max_health = maximum
		health.current = current
		health.dead = current <= 0.0
