extends Node

## Usage: godot --path . --scene res://tools/capture.tscn -- --shot=menu --out=user://shot.png --wait=1.2
## Locked angles for realism-pass before/after:
##   --shot=title --orbit=0.35 --freeze=1
##   --shot=arena --freeze=1
##   --shot=dune_side --freeze=1
##   --shot=dune_fps --freeze=1
##   --shot=placement --freeze=1
##   --shot=mesas --freeze=1

var _shot: String = "menu"
var _out: String = "user://shot.png"
var _wait: float = 1.25
var _orbit: float = 0.35
var _freeze: bool = false
var _elapsed: float = 0.0
var _done: bool = false
var _armed: bool = false
var _vfx_arena: Node
var _vfx_fired: bool = false
var _vfx_stable: int = 0
var _stats_out: String = ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot = arg.substr(7)
		elif arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--wait="):
			_wait = maxf(0.08, float(arg.substr(7)))
		elif arg.begins_with("--orbit="):
			_orbit = float(arg.substr(8))
		elif arg.begins_with("--freeze="):
			_freeze = arg.substr(9) != "0"
		elif arg.begins_with("--stats="):
			_stats_out = arg.substr(8)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(Vector2i(1280, 720))
	GameSettings.set_quality(GameSettings.Quality.ULTRA)
	if _shot.begins_with("menu") or _shot == "title":
		var menu: Node = load("res://scenes/ui/main_menu.tscn").instantiate()
		add_child(menu)
		await get_tree().process_frame
		if menu is MainMenu:
			var mm := menu as MainMenu
			if _freeze or _shot == "title":
				mm.freeze_cinematic(_orbit)
			if _shot == "menu_play":
				mm._show_play()
			elif _shot == "menu_settings":
				mm._show_settings()
			elif _shot == "menu_credits":
				mm._show_credits()
	else:
		Session.selected_mode_id = Ids.MODE_SURVIVE
		Session.start_run(Ids.MODE_SURVIVE)
		var arena: Node = load("res://scenes/world/arena.tscn").instantiate()
		add_child(arena)
		await get_tree().process_frame
		await get_tree().physics_frame
		await get_tree().physics_frame
		_lock_arena_camera(arena)
	_elapsed = 0.0
	_armed = true


func _lock_arena_camera(arena: Node) -> void:
	var player := arena.get_node_or_null("Player") as Node3D
	if player == null:
		return
	if _shot.begins_with("vfx_"):
		_shot_vfx(arena, player, _shot)
		return
	match _shot:
		"dune_side":
			_shot_dune_side(arena, player)
		"dune_fps":
			_seat_player(player, Vector3(7.0, 0.0, -23.5), -1.05, 0.35)
		"dune_fps_forward":
			_seat_player(player, Vector3(7.0, 0.0, -22.0), 0.06, 0.2)
		"placement":
			_shot_placement(arena, player)
		"mesas":
			_shot_mesas(arena, player)
		"mesas_far":
			_shot_mesas_far(arena, player)
		"cover_rocks":
			_shot_cover_rocks(arena, player)
		"close_wall":
			_shot_close_wall(arena, player)
		"close_turret":
			_shot_close_turret(arena, player)
		"inspect_turret":
			_shot_inspect_turret(arena, player)
		"inspect_sell":
			_shot_inspect_sell(arena, player)
		"play_edge":
			_shot_play_edge(arena, player)
		"rifle":
			_seat_player(player, Vector3(0.0, 0.0, 6.0), 0.22, 0.12)
		"wash_fps":
			_seat_player(player, Vector3(-12.2, 0.0, 0.0), -1.12, 0.15)
		_:
			_seat_player(player, Vector3(0.0, 0.0, 6.0), -0.08, 0.0)


func _seat_player(player: Node3D, xz: Vector3, pitch: float, yaw: float) -> void:
	player.global_position = Landscape.seat(xz, 0.12)
	player.rotation = Vector3(0.0, yaw, 0.0)
	if player is PlayerController:
		(player as PlayerController).look_pitch = pitch
	var cam := player.get_node_or_null("Camera3D") as Camera3D
	if cam:
		cam.rotation = Vector3(pitch, 0.0, 0.0)
		cam.current = true


func _shot_dune_side(arena: Node, player: Node3D) -> void:
	if player is PlayerController:
		(player as PlayerController).visible = false
	var ridge := Vector3(10.0, 0.0, -21.0)
	var wall := WallBuilding.new()
	wall.name = "CaptureWall"
	arena.add_child(wall)
	wall.setup(BuildingCatalog.by_id(Ids.WALL), PlacementRules.world_to_cell(Vector3(7.5, 0.0, -19.0)), 7001)
	var cam := Camera3D.new()
	cam.name = "CaptureCam"
	cam.fov = 52.0
	cam.position = Landscape.seat(Vector3(17.5, 0.0, -11.5), 2.2)
	arena.add_child(cam)
	cam.look_at(Landscape.seat(ridge, 0.7), Vector3.UP)
	cam.current = true


func _shot_mesas(arena: Node, player: Node3D) -> void:
	if player is PlayerController:
		(player as PlayerController).visible = false
	var target := Vector3(78.0, 0.0, -96.0)
	var y := Landscape.height_at(target.x, target.z)
	var cam := Camera3D.new()
	cam.name = "CaptureCam"
	cam.fov = 40.0
	cam.position = Vector3(122.0, maxf(8.0, y * 0.42 + 7.5), -54.0)
	arena.add_child(cam)
	cam.look_at(Vector3(target.x, y * 0.62, target.z), Vector3.UP)
	cam.current = true


func _shot_mesas_far(arena: Node, player: Node3D) -> void:
	if player is PlayerController:
		(player as PlayerController).visible = false
	var cam := Camera3D.new()
	cam.name = "CaptureCam"
	cam.fov = 38.0
	cam.position = Landscape.seat(Vector3(-6.0, 0.0, 18.0), 1.6)
	arena.add_child(cam)
	var look := Vector3(78.0, Landscape.height_at(78.0, -96.0) * 0.45, -96.0)
	cam.look_at(look, Vector3.UP)
	cam.current = true


func _shot_cover_rocks(arena: Node, player: Node3D) -> void:
	if player is PlayerController:
		(player as PlayerController).visible = false
	var target := Landscape.seat(Vector3(5.5, 0.0, -3.5), 0.45)
	var cam := Camera3D.new()
	cam.name = "CaptureCam"
	cam.fov = 48.0
	cam.position = Landscape.seat(Vector3(8.4, 0.0, -6.6), 1.35)
	arena.add_child(cam)
	cam.look_at(target, Vector3.UP)
	cam.current = true


func _shot_close_wall(arena: Node, player: Node3D) -> void:
	if player is PlayerController:
		(player as PlayerController).visible = false
	var wall := WallBuilding.new()
	wall.name = "CaptureWallClose"
	arena.add_child(wall)
	wall.setup(BuildingCatalog.by_id(Ids.WALL), PlacementRules.world_to_cell(Vector3(4.0, 0.0, -8.0)), 7101)
	var cam := Camera3D.new()
	cam.name = "CaptureCam"
	cam.fov = 42.0
	cam.position = Landscape.seat(Vector3(7.4, 0.0, -5.2), 1.55)
	arena.add_child(cam)
	cam.look_at(wall.global_position + Vector3(0.0, 1.15, 0.0), Vector3.UP)
	cam.current = true


func _shot_close_turret(arena: Node, player: Node3D) -> void:
	if player is PlayerController:
		(player as PlayerController).visible = false
	var turret := TurretBuilding.new()
	turret.name = "CaptureTurretClose"
	arena.add_child(turret)
	turret.setup(BuildingCatalog.by_id(Ids.TURRET), PlacementRules.world_to_cell(Vector3(3.0, 0.0, -6.0)), 7102)
	var cam := Camera3D.new()
	cam.name = "CaptureCam"
	cam.fov = 40.0
	cam.position = Landscape.seat(Vector3(5.6, 0.0, -3.6), 1.45)
	arena.add_child(cam)
	cam.look_at(turret.global_position + Vector3(0.0, 1.05, 0.0), Vector3.UP)
	cam.current = true


func _shot_inspect_turret(arena: Node, player: Node3D) -> void:
	Session.cmd_gather(Ids.SCRAP, 80)
	Session.cmd_gather(Ids.CRYSTAL, 40)
	var origin := Vector2i(2, -3)
	var placed := Session.cmd_try_place(Ids.TURRET, origin)
	if not bool(placed.get("ok", false)):
		return
	var turret := BuildingFactory.spawn(arena as Arena, Ids.TURRET, origin, int(placed.serial))
	Session.cmd_upgrade_building(int(placed.serial))
	_seat_player(player, Vector3(6.2, 0.0, -2.4), -0.12, 2.2)
	var hud := arena.get_node_or_null("HUD") as Hud
	if hud:
		hud.show_building(int(placed.serial))
	if turret and player is PlayerController:
		(player as PlayerController)._builder.select_serial(int(placed.serial))


func _shot_inspect_sell(arena: Node, player: Node3D) -> void:
	var origin := Vector2i(4, -6)
	var placed := Session.cmd_try_place(Ids.WALL, origin)
	if not bool(placed.get("ok", false)):
		return
	var wall := BuildingFactory.spawn(arena as Arena, Ids.WALL, origin, int(placed.serial))
	var at := PlacementRules.seat_origin(Ids.WALL, origin)
	_seat_player(player, at + Vector3(3.4, 0.0, 2.6), -0.18, 2.45)
	var hud := arena.get_node_or_null("HUD") as Hud
	if hud:
		hud.show_building(int(placed.serial))
		if hud.building_panel:
			hud.building_panel._confirming = true
			hud.building_panel.refresh()
	if wall == null:
		return


func _shot_play_edge(arena: Node, player: Node3D) -> void:
	_seat_player(player, Vector3(32.5, 0.0, 0.0), 0.08, -1.57)
	if player is PlayerController:
		(player as PlayerController).visible = true


func _shot_placement(arena: Node, player: Node3D) -> void:
	_seat_player(player, Vector3(3.8, 0.0, -9.5), -0.22, 0.38)
	if not player is PlayerController:
		return
	var pc := player as PlayerController
	pc.building_mode = true
	var builder := pc.get_node_or_null("Builder") as BuilderController
	if builder == null:
		return
	builder.set_active(true)
	var origin := PlacementRules.world_to_cell(Vector3(10.0, 0.0, -18.0))
	builder._origin = origin
	var def := builder.current()
	if def == null:
		return
	var size := Vector3(float(def.footprint.x) * 1.85, 1.6, float(def.footprint.y) * 1.85)
	(builder._ghost.mesh as BoxMesh).size = size
	var seated := PlacementRules.seat_origin(def.id, origin)
	var basis := PlacementRules.foundation_basis(seated.x, seated.z)
	builder._ghost.global_transform = Transform3D(basis, seated + basis.y * (size.y * 0.5))
	builder._ghost.material_override = builder._ghost_mat(true)
	builder._ghost.visible = true
	builder._valid = true
	builder.last_reason = "LMB place · %s" % def.display_name


func _process(delta: float) -> void:
	if _done or not _armed:
		return
	if _shot.begins_with("vfx_"):
		_vfx_stable += 1
		if not _vfx_fired:
			if _vfx_stable < 18:
				return
			_fire_vfx_now()
			_vfx_fired = true
			_vfx_stable = 0
			return
		var hold := 2
		if _shot == "vfx_corpse":
			hold = 8
		elif _shot == "vfx_death" or _shot == "vfx_explosion":
			hold = 3
		if _vfx_stable < hold:
			return
	else:
		_elapsed += delta
		if _elapsed < _wait:
			return
	_done = true
	await RenderingServer.frame_post_draw
	var draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var prims := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var objects := int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	var fps := int(Performance.get_monitor(Performance.TIME_FPS))
	print("CAPTURE STATS shot=", _shot, " fps=", fps, " draws=", draws, " prims=", prims, " objects=", objects)
	if _stats_out != "":
		var f := FileAccess.open(_stats_out, FileAccess.WRITE)
		if f:
			f.store_string("{\"shot\":\"%s\",\"fps\":%d,\"draws\":%d,\"prims\":%d,\"objects\":%d}\n" % [_shot, fps, draws, prims, objects])
			f.close()
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png(_out)
		print("CAPTURE OK ", _out, " ", img.get_width(), "x", img.get_height())
	else:
		print("CAPTURE FAIL no image")
	get_tree().quit(0)


func _shot_vfx(arena: Node, player: Node3D, kind: String) -> void:
	match kind:
		"vfx_muzzle":
			_wait = 0.07
		"vfx_tracer", "vfx_spell", "vfx_hit_flash":
			_wait = 0.08
		"vfx_corpse":
			_wait = 0.4
		"vfx_death", "vfx_explosion":
			_wait = 0.18
		_:
			_wait = 0.16
	if player is PlayerController:
		(player as PlayerController).visible = false
	var pcam := player.get_node_or_null("Camera3D") as Camera3D
	if pcam:
		pcam.current = false
	for ui_name in ["HUD", "PauseMenu", "EndScreen"]:
		var ui := arena.get_node_or_null(ui_name)
		if ui:
			ui.visible = false
	for child in arena.get_children():
		var n := String(child.name)
		if child is ResourceNode or child is Relic or n.begins_with("Scrap") or n.begins_with("Crystal") or n.begins_with("Relic") or n.begins_with("storage"):
			if child is Node3D:
				(child as Node3D).visible = false
	var stage := Landscape.seat(Vector3(0.0, 0.0, -16.0), 0.0)
	var cam := Camera3D.new()
	cam.name = "CaptureCam"
	cam.fov = 36.0
	cam.position = Landscape.seat(Vector3(3.1, 0.0, -13.4), 1.45)
	arena.add_child(cam)
	cam.look_at(stage + Vector3(0.0, 1.05, 0.0), Vector3.UP)
	cam.current = true
	CombatFx.warmup(arena)
	_vfx_arena = arena
	if kind == "vfx_corpse":
		_wait = 0.4
	elif kind == "vfx_death" or kind == "vfx_explosion":
		_wait = 0.16
	else:
		_wait = 0.12


func _fire_vfx_now() -> void:
	var arena := _vfx_arena
	if arena == null:
		return
	var stage := Landscape.seat(Vector3(0.0, 0.0, -16.0), 0.0)
	var hit_at := stage + Vector3(0.0, 1.15, 0.0)
	match _shot:
		"vfx_muzzle":
			CombatFx.muzzle_flash(arena, hit_at, Color(1.0, 0.78, 0.32), "kinetic", Vector3(0.0, 0.15, 0.4))
		"vfx_tracer":
			var from := hit_at + Vector3(-1.8, 0.35, 0.4)
			var to := hit_at + Vector3(1.8, 0.15, -0.3)
			CombatFx.tracer(arena, from, to, Color(1.0, 0.82, 0.35), "kinetic")
		"vfx_fire":
			var fire_from := hit_at + Vector3(-1.1, 0.2, 0.35)
			CombatFx.muzzle_flash(arena, fire_from, Color(1.0, 0.45, 0.12), "fire", (hit_at - fire_from).normalized())
			CombatFx.tracer(arena, fire_from, hit_at, Color(1.0, 0.45, 0.12), "fire")
			CombatFx.projectile_burst(arena, hit_at, "fire")
		"vfx_ice":
			var bolt := MobProjectile.new()
			bolt.shot_vfx = "ice"
			bolt.direction = Vector3(0, 0, 1)
			bolt.speed = 0.0
			bolt.life = 2.0
			arena.add_child(bolt)
			bolt.global_position = hit_at
			CombatFx.projectile_burst(arena, hit_at, "ice")
		"vfx_spell":
			var spell_from := hit_at + Vector3(-1.1, 0.25, 0.4)
			CombatFx.muzzle_flash(arena, spell_from, Color(0.4, 0.9, 1.0), "spell", (hit_at - spell_from).normalized())
			CombatFx.tracer(arena, spell_from, hit_at, Color(0.4, 0.95, 1.0), "spell")
			CombatFx.projectile_burst(arena, hit_at, "spell")
		"vfx_sparks":
			var tank := _capture_mob(arena, Ids.TANK, stage)
			CombatFx.impact(arena, hit_at, Color(1.0, 0.75, 0.3), tank, Vector3(0, 0, 1))
		"vfx_blood":
			var rusher := _capture_mob(arena, Ids.RUSHER, stage)
			CombatFx.impact(arena, hit_at, Color(0.5, 0.05, 0.05), rusher, Vector3.UP)
		"vfx_bone":
			var ranger := _capture_mob(arena, Ids.RANGER, stage)
			CombatFx.impact(arena, hit_at, Color(0.84, 0.78, 0.62), ranger, Vector3.UP)
		"vfx_dust":
			CombatFx.impact(arena, stage + Vector3(0.0, 0.08, 0.0), Color(0.72, 0.55, 0.34), null, Vector3.UP)
		"vfx_hit_flash":
			var flashed := _capture_mob(arena, Ids.RUSHER, stage)
			CombatFx.hit_flash(flashed, 12.0)
		"vfx_death":
			var dying := _capture_mob(arena, Ids.RUSHER, stage)
			CombatFx.begin_death(dying)
		"vfx_explosion":
			var mech := _capture_mob(arena, Ids.TANK, stage)
			CombatFx.begin_death(mech)
		"vfx_corpse":
			var body := _capture_mob(arena, Ids.RUSHER, stage)
			CombatFx.begin_death(body)
		_:
			CombatFx.muzzle_flash(arena, hit_at, Color(1.0, 0.78, 0.32), "kinetic", Vector3(0, 0, 1))
			CombatFx.tracer(arena, hit_at + Vector3(-1.2, 0.2, 0.3), hit_at, Color(1.0, 0.82, 0.35), "kinetic")


func _capture_mob(arena: Node, mob_id: String, xz: Vector3) -> MobActor:
	var def := MobCatalog.by_id(mob_id)
	var mob := MobActor.new()
	mob.name = "CaptureMob_%s" % mob_id
	arena.add_child(mob)
	mob.configure(def)
	mob.global_position = Landscape.seat(xz, 0.2)
	if mob.has_method("set_physics_process"):
		mob.set_physics_process(false)
	return mob

