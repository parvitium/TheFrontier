class_name WeaponController
extends Node3D

var loadouts: Array[Dictionary] = []
var index: int = 0
var cooldown: float = 0.0
var reloading: float = 0.0
var _view: MeshInstance3D
var _flash: OmniLight3D


func _ready() -> void:
	for def in WeaponCatalog.all():
		loadouts.append({
			"def": def,
			"mag": def.magazine_size,
			"reserve": def.reserve,
		})
	var mat := Greybox.material(Color(0.22, 0.55, 0.62), Color(0.25, 0.85, 0.95), 1.4, 0.35, 0.28)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_view = Greybox.box(Vector3(0.16, 0.16, 0.72), mat, "ViewModel")
	_view.position = Vector3(0.34, -0.26, -0.48)
	add_child(_view)
	_flash = OmniLight3D.new()
	_flash.omni_range = 4.0
	_flash.light_energy = 0.0
	_flash.light_color = Color(0.7, 0.95, 1.0)
	_flash.position = Vector3(0.28, -0.18, -0.8)
	add_child(_flash)
	GameBus.restock_ammo.connect(_restock)
	_refresh_view()


func tick(delta: float, camera: Camera3D, fire_held: bool, fire_tap: bool, reload_tap: bool) -> void:
	cooldown = max(0.0, cooldown - delta)
	_flash.light_energy = max(0.0, _flash.light_energy - delta * 18.0)
	if reloading > 0.0:
		reloading = max(0.0, reloading - delta)
		if reloading == 0.0:
			_finish_reload()
		return
	var def := current_def()
	if reload_tap:
		_start_reload()
		return
	var want_fire := fire_held if def.automatic else fire_tap
	if want_fire and cooldown <= 0.0:
		_fire(camera)


func current_def() -> WeaponDef:
	return loadouts[index]["def"]


func ammo_text() -> String:
	if reloading > 0.0:
		return "RELOADING"
	return "%d / %d" % [loadouts[index]["mag"], loadouts[index]["reserve"]]


func equip(i: int) -> void:
	if i < 0 or i >= loadouts.size():
		return
	index = i
	reloading = 0.0
	_refresh_view()


func _fire(camera: Camera3D) -> void:
	var pack: Dictionary = loadouts[index]
	var def: WeaponDef = pack["def"]
	if pack["mag"] <= 0:
		_start_reload()
		return
	pack["mag"] = int(pack["mag"]) - 1
	cooldown = def.fire_interval
	_flash.light_energy = 3.4
	var origin := camera.global_position
	var forward := -camera.global_transform.basis.z
	var space := camera.get_world_3d()
	var exclude: Array[RID] = []
	var player := get_parent()
	while player and not player is CharacterBody3D:
		player = player.get_parent()
	if player is CollisionObject3D:
		exclude.append((player as CollisionObject3D).get_rid())
	for _i in def.pellets:
		Hitscan.fire(space, origin, forward, def.range, exclude, def.damage, self, def.spread_degrees)


func _start_reload() -> void:
	var pack: Dictionary = loadouts[index]
	var def: WeaponDef = pack["def"]
	if pack["mag"] >= def.magazine_size or pack["reserve"] <= 0 or reloading > 0.0:
		return
	reloading = def.reload_time


func _finish_reload() -> void:
	var pack: Dictionary = loadouts[index]
	var def: WeaponDef = pack["def"]
	var need: int = def.magazine_size - int(pack["mag"])
	var take: int = mini(need, int(pack["reserve"]))
	pack["mag"] = int(pack["mag"]) + take
	pack["reserve"] = int(pack["reserve"]) - take


func _restock() -> void:
	for pack in loadouts:
		var def: WeaponDef = pack["def"]
		var missing: int = def.reserve - int(pack["reserve"])
		if missing > 0:
			pack["reserve"] = int(pack["reserve"]) + max(1, int(ceil(float(missing) * 0.35)))


func _refresh_view() -> void:
	var mat: StandardMaterial3D
	if index == 0:
		_view.scale = Vector3(1, 1, 1.15)
		mat = Greybox.material(Color(0.25, 0.62, 0.7), Color(0.3, 0.9, 1.0), 1.6, 0.35, 0.28)
	else:
		_view.scale = Vector3(1.35, 0.85, 0.75)
		mat = Greybox.material(Color(0.72, 0.38, 0.22), Color(1.0, 0.5, 0.15), 1.4, 0.3, 0.35)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_view.material_override = mat
