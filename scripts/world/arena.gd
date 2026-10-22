class_name Arena
extends Node3D

var _nav_dirty: bool = false
var _nav_cooldown: float = 0.0


func _ready() -> void:
	if Session.state.mode_id == "" or not Session.state.is_running():
		Session.start_run(Session.selected_mode_id)
	_ensure_nav_tree()
	WorldBuilder.build(self)
	_add_player()
	_add_director()
	_add_hud()
	GameBus.nav_dirty.connect(_on_nav_dirty)
	GameBus.wave_cleared.connect(_on_wave_cleared)
	call_deferred("rebake_nav")


func _physics_process(delta: float) -> void:
	Session.tick(delta)
	if _nav_dirty:
		_nav_cooldown -= delta
		if _nav_cooldown <= 0.0:
			_nav_dirty = false
			rebake_nav()


func _ensure_nav_tree() -> void:
	var region := NavigationRegion3D.new()
	region.name = "NavigationRegion3D"
	var mesh := NavigationMesh.new()
	mesh.cell_size = 0.4
	mesh.cell_height = 0.3
	mesh.agent_radius = 0.4
	mesh.agent_height = 1.8
	mesh.agent_max_climb = 0.3
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	region.navigation_mesh = mesh
	var geometry := Node3D.new()
	geometry.name = "Geometry"
	region.add_child(geometry)
	var obstacles := Node3D.new()
	obstacles.name = "Obstacles"
	region.add_child(obstacles)
	add_child(region)


func _add_player() -> void:
	var player := PlayerController.new()
	player.name = "Player"
	player.position = Vector3(0, 0.1, 6)
	add_child(player)


func _add_director() -> void:
	var director := WaveDirector.new()
	director.name = "WaveDirector"
	add_child(director)


func _add_hud() -> void:
	var hud := Hud.new()
	hud.name = "HUD"
	add_child(hud)
	var pause := PauseMenu.new()
	pause.name = "PauseMenu"
	add_child(pause)
	var end_screen := EndScreen.new()
	end_screen.name = "EndScreen"
	add_child(end_screen)


func _on_nav_dirty() -> void:
	_nav_dirty = true
	_nav_cooldown = 0.12


func _on_wave_cleared(_index: int) -> void:
	for node in get_tree().get_nodes_in_group("resource_nodes"):
		if node is ResourceNode:
			(node as ResourceNode).restock()


func rebake_nav() -> void:
	var region := get_node_or_null("NavigationRegion3D") as NavigationRegion3D
	if region:
		region.bake_navigation_mesh(false)


func obstacle_root() -> Node3D:
	return get_node("NavigationRegion3D/Obstacles") as Node3D
