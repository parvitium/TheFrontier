class_name MobActor
extends CharacterBody3D

var def: MobDef
var hp_mult: float = 1.0
var dmg_mult: float = 1.0
var slow_factor: float = 1.0
var _slow_time: float = 0.0
var _melee_cd: float = 0.0
var _ranged_cd: float = 0.0
var _retarget: float = 0.0
var _agent: NavigationAgent3D
var _focus: Node3D


func configure(p_def: MobDef, p_hp_mult: float = 1.0, p_dmg_mult: float = 1.0) -> void:
	def = p_def
	hp_mult = p_hp_mult
	dmg_mult = p_dmg_mult
	add_to_group("mobs")
	add_to_group("damageable")
	collision_layer = 4
	collision_mask = 1 | 2 | 8 | 32
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = def.radius
	shape.height = def.height
	col.shape = shape
	col.position.y = def.height * 0.5
	add_child(col)
	var visual := Node3D.new()
	visual.name = "Visual"
	visual.set_meta("asset_slot", "mob_%s" % def.id)
	var body := Greybox.cylinder(def.radius, def.height * 0.7, Greybox.material(def.color, def.color, 0.35, 0.1, 0.55), "Body")
	body.position.y = def.height * 0.45
	visual.add_child(body)
	var head := Greybox.sphere(def.radius * 0.7, Greybox.material(def.color.lightened(0.15), def.color, 0.6, 0.05, 0.4), "Head")
	head.position.y = def.height * 0.92
	visual.add_child(head)
	add_child(visual)
	_agent = NavigationAgent3D.new()
	_agent.path_desired_distance = 0.55
	_agent.target_desired_distance = 1.4
	_agent.avoidance_enabled = false
	_agent.radius = def.radius
	_agent.height = def.height
	add_child(_agent)
	var health := Health.new()
	health.name = "Health"
	health.configure(def.max_health * hp_mult, "mob")
	health.died.connect(_on_died)
	add_child(health)


func apply_slow(factor: float, duration: float) -> void:
	slow_factor = minf(slow_factor, factor)
	_slow_time = maxf(_slow_time, duration)


func _physics_process(delta: float) -> void:
	if def == null or not Session.state.is_running():
		return
	if _slow_time > 0.0:
		_slow_time -= delta
		if _slow_time <= 0.0:
			slow_factor = 1.0
	_melee_cd = max(0.0, _melee_cd - delta)
	_ranged_cd = max(0.0, _ranged_cd - delta)
	_retarget -= delta
	if _retarget <= 0.0 or not is_instance_valid(_focus):
		_focus = _pick_focus()
		_retarget = 0.35
	if _focus == null:
		return
	var to_focus := _focus.global_position - global_position
	to_focus.y = 0.0
	var dist := to_focus.length()
	if def.ranged_damage > 0.0 and dist <= def.ranged_range and dist >= def.preferred_range * 0.65:
		_try_ranged()
		if dist < def.preferred_range * 0.75:
			_move(-to_focus.normalized(), delta)
			return
		if dist <= def.preferred_range:
			velocity.x = 0.0
			velocity.z = 0.0
			velocity.y -= 18.0 * delta
			move_and_slide()
			return
	if dist <= def.melee_range + 0.2:
		_try_melee(_focus)
	_chase(_focus, delta)
	_maybe_break_walls()


func _chase(target: Node3D, delta: float) -> void:
	_agent.target_position = target.global_position
	var next := _agent.get_next_path_position()
	var dir := next - global_position
	dir.y = 0.0
	if dir.length() > 0.05:
		dir = dir.normalized()
		var speed := def.move_speed * slow_factor
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	move_and_slide()
	if dir.length() > 0.1:
		var look := global_position + dir
		if absf(dir.dot(Vector3.UP)) < 0.995:
			look_at(look, Vector3.UP)


func _move(dir: Vector3, delta: float) -> void:
	dir.y = 0.0
	if dir.length() > 0.01:
		dir = dir.normalized()
		velocity.x = dir.x * def.move_speed * 0.7 * slow_factor
		velocity.z = dir.z * def.move_speed * 0.7 * slow_factor
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	move_and_slide()


func _pick_focus() -> Node3D:
	var primary := _pick_primary()
	if primary != null and not _should_breach(primary):
		return primary
	var breach := _pick_breach_building()
	if breach != null:
		return breach
	return primary


func _pick_primary() -> Node3D:
	var core := get_tree().get_first_node_in_group("core") as Node3D
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var player_ok := player != null and Session.state.player_alive
	match def.target_bias:
		MobDef.TargetBias.CORE:
			return core
		MobDef.TargetBias.PLAYER:
			return player if player_ok else core
		MobDef.TargetBias.HYBRID:
			if player_ok and global_position.distance_to(player.global_position) <= def.aggro_radius:
				return player
			return core
	return core


func _should_breach(target: Node3D) -> bool:
	var from := PlacementRules.world_to_cell(global_position)
	var enclosed := not BreachRules.core_reachable(Session.state.occupied_cells, from)
	if enclosed:
		if target != null and target.is_in_group("player") and _agent_can_reach(target):
			return false
		return true
	return _agent_unreachable_far(target)


func _agent_can_reach(target: Node3D) -> bool:
	if _agent == null or target == null:
		return true
	_agent.target_position = target.global_position
	return _agent.is_target_reachable()


func _agent_unreachable_far(target: Node3D) -> bool:
	if _agent == null or target == null:
		return false
	_agent.target_position = target.global_position
	if not _agent.is_target_reachable():
		return true
	var to := target.global_position - global_position
	to.y = 0.0
	return _agent.is_navigation_finished() and to.length() > def.melee_range + 1.2


func _pick_breach_building() -> Node3D:
	var from := PlacementRules.world_to_cell(global_position)
	var serials := BreachRules.blocking_serials(Session.state.occupied_cells, from)
	var best := _nearest_blocking(serials)
	if best != null:
		return best
	return _nearest_blocking([])


func _nearest_blocking(serials: Array[int]) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("buildings"):
		if not node is BuildingBase:
			continue
		var building := node as BuildingBase
		if serials.size() > 0 and not serials.has(building.serial):
			continue
		var bdef := BuildingCatalog.by_id(building.building_id)
		if bdef == null or not bdef.blocks_navigation:
			continue
		var d := global_position.distance_to(building.global_position)
		if d < best_d:
			best_d = d
			best = building
	return best


func _try_melee(target: Node3D) -> void:
	if _melee_cd > 0.0:
		return
	_melee_cd = def.melee_interval
	_deal(target, def.melee_damage * dmg_mult)


func _try_ranged() -> void:
	if _ranged_cd > 0.0 or _focus == null:
		return
	_ranged_cd = def.ranged_interval
	var bolt := MobProjectile.new()
	bolt.damage = def.ranged_damage * dmg_mult
	bolt.global_position = global_position + Vector3(0, def.height * 0.7, 0)
	var aim := _focus.global_position + Vector3(0, 1.2, 0)
	bolt.direction = (aim - bolt.global_position).normalized()
	get_tree().current_scene.add_child(bolt)


func _maybe_break_walls() -> void:
	if _melee_cd > 0.0:
		return
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.8, 0), global_position + Vector3(0, 0.8, 0) - global_transform.basis.z * 1.8)
	query.collision_mask = 8
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	_melee_cd = def.melee_interval
	_deal(hit.collider, def.melee_damage * dmg_mult)


func _deal(target: Object, amount: float) -> void:
	if target == null or not target is Node:
		return
	Session.cmd_resolve_hit("mob", target, amount)


func _on_died(_source: Node) -> void:
	Session.cmd_mob_killed(def.id if def else Ids.RUSHER)
	queue_free()
