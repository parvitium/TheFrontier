class_name WeaponController
extends Node3D

var _view: MeshInstance3D
var _flash: OmniLight3D


func _ready() -> void:
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
	_refresh_view()


func tick(delta: float, camera: Camera3D, fire_held: bool, fire_tap: bool, reload_tap: bool) -> void:
	_flash.light_energy = max(0.0, _flash.light_energy - delta * 18.0)
	if reload_tap:
		Session.cmd_start_reload()
		return
	var def := current_def()
	if def == null:
		return
	var want_fire := fire_held if def.automatic else fire_tap
	if want_fire:
		var shot := Session.cmd_try_fire()
		if shot.ok:
			_flash.light_energy = 3.4
			_hitscan(camera, shot)


func current_def() -> WeaponDef:
	return Session.current_weapon_def()


func ammo_text() -> String:
	return Session.ammo_text()


func equip(i: int) -> void:
	Session.cmd_select_weapon(i)
	_refresh_view()


func _hitscan(camera: Camera3D, shot: Dictionary) -> void:
	var origin := camera.global_position
	var forward := -camera.global_transform.basis.z
	var space := camera.get_world_3d()
	var exclude: Array[RID] = []
	var player := get_parent()
	while player and not player is CharacterBody3D:
		player = player.get_parent()
	if player is CollisionObject3D:
		exclude.append((player as CollisionObject3D).get_rid())
	var pellets := int(shot.pellets)
	var damage := float(shot.damage)
	var spread := float(shot.spread)
	var reach := float(shot.range)
	for _i in pellets:
		Hitscan.fire(space, origin, forward, reach, exclude, damage, self, spread)


func _refresh_view() -> void:
	var mat: StandardMaterial3D
	if Session.state.selected_weapon == 0:
		_view.scale = Vector3(1, 1, 1.15)
		mat = Greybox.material(Color(0.25, 0.62, 0.7), Color(0.3, 0.9, 1.0), 1.6, 0.35, 0.28)
	else:
		_view.scale = Vector3(1.35, 0.85, 0.75)
		mat = Greybox.material(Color(0.72, 0.38, 0.22), Color(1.0, 0.5, 0.15), 1.4, 0.3, 0.35)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_view.material_override = mat
