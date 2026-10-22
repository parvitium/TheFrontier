class_name WeaponController
extends Node3D

var _view: Node3D
var _flash: OmniLight3D
var _recoil: float = 0.0
var _muzzle: Node3D


func _ready() -> void:
	_flash = OmniLight3D.new()
	_flash.omni_range = 4.5
	_flash.light_energy = 0.0
	_flash.light_color = Color(1.0, 0.82, 0.4)
	_flash.position = Vector3(0.18, -0.12, -0.72)
	add_child(_flash)
	_refresh_view()


func tick(delta: float, camera: Camera3D, fire_held: bool, fire_tap: bool, reload_tap: bool) -> void:
	_flash.light_energy = max(0.0, _flash.light_energy - delta * 22.0)
	_recoil = max(0.0, _recoil - delta * 9.0)
	if _view:
		_view.position = Vector3(0.28, -0.22, -0.48) + Vector3(0.0, _recoil * 0.012, _recoil * 0.04)
		_view.rotation_degrees = Vector3(4.0 + _recoil * 3.5, 6.0, 2.0)
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
			_flash.light_energy = 4.2
			_recoil = 1.0
			var muzzle_pos := _muzzle.global_position if _muzzle else camera.global_position - camera.global_transform.basis.z * 0.7
			CombatFx.muzzle_flash(self, muzzle_pos, Color(1.0, 0.78, 0.32) if Session.state.selected_weapon == 0 else Color(1.0, 0.55, 0.2))
			Sfx.play("fire_rifle" if Session.state.selected_weapon == 0 else "fire_shotgun", randf_range(0.94, 1.06))
			_hitscan(camera, shot, muzzle_pos)


func current_def() -> WeaponDef:
	return Session.current_weapon_def()


func ammo_text() -> String:
	return Session.ammo_text()


func equip(i: int) -> void:
	Session.cmd_select_weapon(i)
	_refresh_view()


func _hitscan(camera: Camera3D, shot: Dictionary, muzzle_pos: Vector3) -> void:
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
	var host := camera.get_tree().current_scene
	for _i in pellets:
		var hit := Hitscan.fire(space, origin, forward, reach, exclude, damage, self, spread)
		var dest: Vector3
		if bool(hit.get("hit", false)):
			dest = hit.position
			CombatFx.impact(host, dest)
		else:
			var dir: Vector3 = hit.get("dir", forward)
			dest = origin + dir * reach
		CombatFx.tracer(host, muzzle_pos, dest)


func _refresh_view() -> void:
	if _view:
		_view.queue_free()
		_view = null
		_muzzle = null
	var slot := "pulse_rifle" if Session.state.selected_weapon == 0 else "scatter_cannon"
	_view = VisualKit.instance(slot)
	if _view == null:
		var mat := PbrLibrary.metal(Color(0.25, 0.62, 0.7) if Session.state.selected_weapon == 0 else Color(0.72, 0.38, 0.22), 0.55, 0.7)
		_view = Greybox.box(Vector3(0.16, 0.16, 0.72), mat, "ViewModel")
	_view.name = "ViewModel"
	_view.position = Vector3(0.28, -0.22, -0.48)
	_view.rotation_degrees = Vector3(4.0, 6.0, 2.0)
	_view.scale = Vector3(1.35, 1.35, 1.35)
	_prepare_viewmodel(_view)
	add_child(_view)
	_muzzle = VisualKit.find_node(_view, "Muzzle")
	if _muzzle and _muzzle.is_inside_tree():
		_flash.global_position = _muzzle.global_position
	else:
		_flash.position = Vector3(0.02, -0.02, -0.7)


func _prepare_viewmodel(root: Node) -> void:
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi == null:
			continue
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		var src: Material = mi.material_override
		if src == null:
			src = mi.get_active_material(0)
		var mat_name: String = src.resource_name if src else mi.name
		var n: String = mat_name.to_lower()
		if "emissive" in n:
			mi.material_override = PbrLibrary.emissive(Color(0.35, 0.9, 1.0), 1.6)
		elif "rubber" in n or "dark" in n:
			mi.material_override = PbrLibrary.metal(Color(0.16, 0.17, 0.18), 0.75, 0.85, false)
		else:
			mi.material_override = PbrLibrary.metal(Color(0.55, 0.58, 0.6), 0.8, 0.75, false)
