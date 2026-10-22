class_name MobCatalog
extends RefCounted


static func all() -> Array[MobDef]:
	var list: Array[MobDef] = []
	list.append(_rusher())
	list.append(_ranger())
	list.append(_tank())
	return list


static func by_id(id: String) -> MobDef:
	for def in all():
		if def.id == id:
			return def
	return null


static func _rusher() -> MobDef:
	var d := MobDef.new()
	d.id = Ids.RUSHER
	d.display_name = "Rusher"
	d.max_health = 40.0
	d.move_speed = 7.0
	d.melee_damage = 8.0
	d.melee_range = 1.6
	d.melee_interval = 0.55
	d.target_bias = MobDef.TargetBias.HYBRID
	d.aggro_radius = 18.0
	d.color = Color(0.86, 0.22, 0.18)
	d.radius = 0.38
	d.height = 1.5
	return d


static func _ranger() -> MobDef:
	var d := MobDef.new()
	d.id = Ids.RANGER
	d.display_name = "Ranger"
	d.max_health = 30.0
	d.move_speed = 3.6
	d.melee_damage = 4.0
	d.melee_range = 1.4
	d.melee_interval = 0.8
	d.ranged_damage = 7.0
	d.ranged_range = 18.0
	d.ranged_interval = 1.15
	d.preferred_range = 13.0
	d.target_bias = MobDef.TargetBias.PLAYER
	d.aggro_radius = 28.0
	d.color = Color(0.62, 0.28, 0.86)
	d.radius = 0.4
	d.height = 1.7
	return d


static func _tank() -> MobDef:
	var d := MobDef.new()
	d.id = Ids.TANK
	d.display_name = "Tank"
	d.max_health = 160.0
	d.move_speed = 2.15
	d.melee_damage = 16.0
	d.melee_range = 2.0
	d.melee_interval = 1.05
	d.target_bias = MobDef.TargetBias.CORE
	d.aggro_radius = 8.0
	d.color = Color(0.28, 0.32, 0.36)
	d.radius = 0.7
	d.height = 2.1
	return d
