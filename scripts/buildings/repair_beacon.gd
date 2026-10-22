class_name RepairBeacon
extends BuildingBase

const RADIUS := 9.0
const CORE_HPS := 4.0
const BUILDING_HPS := 6.0
const PLAYER_HPS := 3.0


func _build_visual(visual: Node3D, def: BuildingDef, _size: Vector3) -> void:
	var dish := Greybox.cylinder(0.7, 0.25, Greybox.material(def.color, Color(0.3, 1.0, 0.5), 1.5, 0.2, 0.35), "Dish")
	dish.position.y = 1.3
	visual.add_child(dish)
	var stem := Greybox.cylinder(0.14, 1.2, Greybox.material(Color(0.3, 0.34, 0.32), Color.BLACK, 0.0, 0.3, 0.4), "Stem")
	stem.position.y = 0.6
	visual.add_child(stem)


func _physics_process(delta: float) -> void:
	if not Session.state.is_running():
		return
	if global_position.distance_to(Vector3.ZERO) <= RADIUS:
		Session.cmd_heal_core(CORE_HPS * delta)
	for node in get_tree().get_nodes_in_group("buildings"):
		if node == self:
			continue
		if node is Node3D and global_position.distance_to((node as Node3D).global_position) <= RADIUS:
			var health := node.get_node_or_null("Health") as Health
			if health:
				health.heal(BUILDING_HPS * delta)
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player and global_position.distance_to(player.global_position) <= RADIUS:
		Session.cmd_heal_player(PLAYER_HPS * delta)
