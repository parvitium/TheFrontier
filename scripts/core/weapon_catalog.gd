class_name WeaponCatalog
extends RefCounted


static func all() -> Array[WeaponDef]:
	return [_rifle(), _shotgun()]


static func by_id(id: String) -> WeaponDef:
	for def in all():
		if def.id == id:
			return def
	return null


static func _rifle() -> WeaponDef:
	var d := WeaponDef.new()
	d.id = Ids.RIFLE
	d.display_name = "Pulse Rifle"
	d.damage = 11.0
	d.pellets = 1
	d.spread_degrees = 0.7
	d.fire_interval = 0.11
	d.magazine_size = 30
	d.reserve = 90
	d.reload_time = 1.8
	d.range = 90.0
	d.automatic = true
	return d


static func _shotgun() -> WeaponDef:
	var d := WeaponDef.new()
	d.id = Ids.SHOTGUN
	d.display_name = "Scatter Cannon"
	d.damage = 7.0
	d.pellets = 8
	d.spread_degrees = 7.5
	d.fire_interval = 0.75
	d.magazine_size = 6
	d.reserve = 24
	d.reload_time = 2.4
	d.range = 28.0
	d.automatic = false
	return d
