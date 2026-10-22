class_name TurretBuilding
extends BuildingBase

const RANGE := 18.0
const INTERVAL := 0.4
const DAMAGE := 15.0

var _cooldown: float = 0.0
var _head: Node3D


func _build_visual(visual: Node3D, def: BuildingDef, size: Vector3) -> void:
	var base := Greybox.cylinder(0.55, 0.45, Greybox.material(def.color.darkened(0.2), Color.BLACK, 0.0, 0.3, 0.4), "Base")
	base.position.y = 0.22
	visual.add_child(base)
	_head = Greybox.box(Vector3(0.45, 0.28, 0.9), Greybox.material(def.color, Color(0.4, 0.9, 1.0), 1.2, 0.4, 0.3), "Head")
	_head.position.y = 1.05
	visual.add_child(_head)
	var pole := Greybox.cylinder(0.12, 0.8, Greybox.material(Color(0.25, 0.28, 0.3), Color.BLACK, 0.0, 0.4, 0.35), "Pole")
	pole.position.y = 0.7
	visual.add_child(pole)


func _physics_process(delta: float) -> void:
	if not Session.state.is_running():
		return
	_cooldown = max(0.0, _cooldown - delta)
	var target := _nearest_mob()
	if target == null:
		return
	var look := target.global_position
	look.y = _head.global_position.y if _head else look.y
	if _head:
		_head.look_at(look, Vector3.UP)
	if _cooldown <= 0.0 and _has_line_of_sight(target):
		_cooldown = INTERVAL
		var health := target.get_node_or_null("Health") as Health
		if health:
			health.apply(DAMAGE, self)


func _has_line_of_sight(target: Node3D) -> bool:
	var from := global_position + Vector3(0, 1.1, 0)
	var to := target.global_position + Vector3(0, 1.0, 0)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1 | 8
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty()


func _nearest_mob() -> Node3D:
	var best: Node3D = null
	var best_d := RANGE
	for node in get_tree().get_nodes_in_group("mobs"):
		if node is Node3D:
			var d := global_position.distance_to((node as Node3D).global_position)
			if d < best_d:
				best_d = d
				best = node
	return best
