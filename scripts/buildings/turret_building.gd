class_name TurretBuilding
extends BuildingBase

const RANGE := 18.0
const INTERVAL := 0.4
const DAMAGE := 15.0

var _head: Node3D
var _kit: Node3D


func setup(def: BuildingDef, origin: Vector2i, p_serial: int) -> void:
	super.setup(def, origin, p_serial)
	if not GameBus.building_upgraded.is_connected(_on_upgraded):
		GameBus.building_upgraded.connect(_on_upgraded)
	_apply_tier_look(Session.state.building_tier(serial))


func _build_visual(visual: Node3D, def: BuildingDef, _size: Vector3) -> void:
	_kit = visual
	if VisualKit.fill(visual, "building_turret") != null:
		_head = VisualKit.find_node(visual, "Head")
		if _head == null:
			_head = visual
		return
	var base := Greybox.cylinder(0.55, 0.45, PbrLibrary.concrete(def.color.darkened(0.2)), "Base")
	base.position.y = 0.22
	visual.add_child(base)
	_head = Greybox.box(Vector3(0.45, 0.28, 0.9), PbrLibrary.metal(def.color, 0.55, 0.7), "Head")
	_head.position.y = 1.05
	visual.add_child(_head)
	var pole := Greybox.cylinder(0.12, 0.8, PbrLibrary.metal(Color(0.3, 0.32, 0.34)), "Pole")
	pole.position.y = 0.7
	visual.add_child(pole)


func _physics_process(_delta: float) -> void:
	if not Session.state.is_running():
		return
	var st := TurretUpgrades.stats(Session.state.building_tier(serial))
	var target := _nearest_mob(float(st.range))
	if target == null:
		return
	var look := target.global_position
	look.y = _head.global_position.y if _head else look.y
	if _head:
		var dir := look - _head.global_position
		if dir.length() > 0.05 and absf(dir.normalized().dot(Vector3.UP)) < 0.995:
			_head.look_at(look, Vector3.UP)
	if _has_line_of_sight(target):
		if Session.cmd_try_turret_fire(serial, target, float(st.damage), float(st.interval)):
			var muzzle := VisualKit.find_node(self, "Muzzle")
			var from := muzzle.global_position if muzzle else global_position + Vector3(0, 1.15, 0)
			var to := target.global_position + Vector3(0, 1.0, 0)
			var host: Node = get_tree().current_scene
			var col := Color(0.4, 0.95, 1.0)
			CombatFx.muzzle_flash(self, from, col, FxSurface.SHOT_SPELL, (to - from).normalized())
			CombatFx.tracer(host, from, to, col, FxSurface.SHOT_SPELL)
			CombatFx.impact(host, to, col, target, (from - to).normalized())
			Sfx.play("turret_shot", randf_range(0.92, 1.08))


func _has_line_of_sight(target: Node3D) -> bool:
	var from := global_position + Vector3(0, 1.1, 0)
	var to := target.global_position + Vector3(0, 1.0, 0)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1 | 8
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty()


func _on_upgraded(p_serial: int, tier: int) -> void:
	if p_serial != serial:
		return
	_apply_tier_look(tier)


func _apply_tier_look(tier: int) -> void:
	var visual := get_node_or_null("Visual") as Node3D
	if visual == null:
		return
	var extra := visual.get_node_or_null("UpgradeKit")
	if extra:
		visual.remove_child(extra)
		extra.free()
	if tier <= 0:
		visual.scale = Vector3.ONE
		return
	var kit := Node3D.new()
	kit.name = "UpgradeKit"
	var col := Color(0.25, 0.82, 0.78) if tier == 1 else Color(0.95, 0.72, 0.28)
	var ring := Greybox.cylinder(0.62 + 0.08 * float(tier), 0.1, PbrLibrary.metal(col, 0.35, 0.85), "Ring")
	ring.position.y = 0.48
	kit.add_child(ring)
	var dish := Greybox.box(Vector3(0.22, 0.12, 0.55), PbrLibrary.emissive(col, 6.0 + 3.0 * float(tier)), "Dish")
	dish.position.y = 1.22
	kit.add_child(dish)
	if tier >= 2:
		var vane := Greybox.box(Vector3(0.12, 0.55, 0.12), PbrLibrary.metal(Color(0.85, 0.78, 0.4), 0.4, 0.7), "Vane")
		vane.position.y = 1.55
		kit.add_child(vane)
	visual.add_child(kit)
	visual.scale = Vector3.ONE * (1.0 + 0.08 * float(tier))


func _nearest_mob(range_m: float = RANGE) -> Node3D:
	var best: Node3D = null
	var best_d := range_m
	for node in get_tree().get_nodes_in_group("mobs"):
		if node is Node3D:
			var d := global_position.distance_to((node as Node3D).global_position)
			if d < best_d:
				best_d = d
				best = node
	return best
