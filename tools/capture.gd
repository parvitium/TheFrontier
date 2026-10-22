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


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot = arg.substr(7)
		elif arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--wait="):
			_wait = maxf(0.4, float(arg.substr(7)))
		elif arg.begins_with("--orbit="):
			_orbit = float(arg.substr(8))
		elif arg.begins_with("--freeze="):
			_freeze = arg.substr(9) != "0"
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


func _lock_arena_camera(arena: Node) -> void:
	var player := arena.get_node_or_null("Player") as Node3D
	if player == null:
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
	if _done:
		return
	_elapsed += delta
	if _elapsed < _wait:
		return
	_done = true
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png(_out)
		print("CAPTURE OK ", _out, " ", img.get_width(), "x", img.get_height())
	else:
		print("CAPTURE FAIL no image")
	get_tree().quit(0)
