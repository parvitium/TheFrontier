class_name PlayerController
extends CharacterBody3D

const WALK_SPEED := 6.2
const SPRINT_SPEED := 9.4
const JUMP_VELOCITY := 5.6
const GRAVITY := 18.0
const MOUSE_SENS := 0.0022

var look_pitch: float = 0.0
var building_mode: bool = false
var _camera: Camera3D
var _weapons: WeaponController
var _builder: BuilderController
var _interact_label: String = ""


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 4 | 8 | 32
	floor_max_angle = deg_to_rad(52.0)
	floor_snap_length = 0.35
	_build_body()
	_weapons = WeaponController.new()
	_weapons.name = "Weapons"
	_camera.add_child(_weapons)
	_builder = BuilderController.new()
	_builder.name = "Builder"
	add_child(_builder)
	var health := Health.new()
	health.name = "Health"
	health.configure(Session.state.player_max_health, "player")
	add_child(health)
	GameBus.player_died.connect(_on_died)
	GameBus.player_respawned.connect(_on_respawned)
	GameBus.player_health_changed.connect(_sync_health)
	sync_mouse_mode()


func _build_body() -> void:
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.36
	shape.height = 1.7
	col.shape = shape
	col.position.y = 0.85
	add_child(col)
	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	_camera.position = Vector3(0, 1.55, 0)
	_camera.fov = GameSettings.fov
	add_child(_camera)
	if not GameSettings.changed.is_connected(_apply_look_settings):
		GameSettings.changed.connect(_apply_look_settings)
	var visual := Node3D.new()
	visual.name = "Visual"
	visual.set_meta("asset_slot", "player")
	add_child(visual)


func _input(event: InputEvent) -> void:
	if _is_headless() or not Session.state.player_alive or get_tree().paused:
		return
	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			sync_mouse_mode()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		apply_look(event.relative)


func _unhandled_input(event: InputEvent) -> void:
	if _is_headless() or not Session.state.player_alive or get_tree().paused:
		return
	if event.is_action_pressed("build_mode"):
		_toggle_build()
	if event.is_action_pressed("weapon_1"):
		_set_build(false)
		_weapons.equip(0)
	if event.is_action_pressed("weapon_2"):
		_set_build(false)
		_weapons.equip(1)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		sync_mouse_mode()


static func gameplay_mouse_mode(paused: bool, in_menu: bool = false) -> Input.MouseMode:
	if paused or in_menu:
		return Input.MOUSE_MODE_VISIBLE
	return Input.MOUSE_MODE_CAPTURED


func sync_mouse_mode() -> void:
	if _is_headless() or get_tree() == null:
		return
	Input.mouse_mode = gameplay_mouse_mode(get_tree().paused)


func apply_look(relative: Vector2) -> void:
	var sens := MOUSE_SENS * GameSettings.mouse_sensitivity
	rotate_y(-relative.x * sens)
	var pitch_delta := relative.y * sens
	if GameSettings.invert_y:
		pitch_delta = -pitch_delta
	look_pitch = clampf(look_pitch + pitch_delta, deg_to_rad(-85.0), deg_to_rad(85.0))
	if _camera:
		_camera.rotation.x = look_pitch


func _physics_process(delta: float) -> void:
	if not Session.state.player_alive:
		velocity = Vector3.ZERO
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	if Input.is_action_just_pressed("jump") and is_on_floor() and not building_mode:
		velocity.y = JUMP_VELOCITY
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var basis_flat := global_transform.basis
	var wish := (basis_flat * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var speed := SPRINT_SPEED if Input.is_action_pressed("sprint") and not building_mode else WALK_SPEED
	if building_mode:
		speed = 5.0
	velocity.x = wish.x * speed
	velocity.z = wish.z * speed
	move_and_slide()
	if building_mode:
		_builder.update_ghost(_camera)
		if Input.is_action_just_pressed("fire"):
			_builder.try_place()
		if Input.is_action_just_pressed("dismantle") or Input.is_action_just_pressed("alt_fire"):
			_builder.try_dismantle(_camera)
	else:
		_weapons.tick(delta, _camera, Input.is_action_pressed("fire"), Input.is_action_just_pressed("fire"), Input.is_action_just_pressed("reload"))
	_try_gather(delta)


func _try_gather(delta: float) -> void:
	_interact_label = ""
	var hit := _aim_body(4.2)
	if hit.is_empty():
		return
	var collider: Object = hit.collider
	if collider is ResourceNode:
		var node := collider as ResourceNode
		_interact_label = "Hold E — gather %s (%d)" % [node.resource_type, node.remaining]
		if Input.is_action_pressed("interact"):
			var gained := node.gather(delta)
			if gained > 0:
				Session.cmd_gather(node.resource_type, gained)
	elif collider is Relic:
		_interact_label = "Press E — recover relic"
		if Input.is_action_just_pressed("interact"):
			(collider as Relic).collect()


func _aim_body(distance: float) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(_camera.global_position, _camera.global_position - _camera.global_transform.basis.z * distance)
	query.exclude = [get_rid()]
	query.collision_mask = 64 | 8 | 32
	return get_world_3d().direct_space_state.intersect_ray(query)


func _toggle_build() -> void:
	_set_build(not building_mode)


func _set_build(enabled: bool) -> void:
	building_mode = enabled
	_builder.set_active(enabled)
	_weapons.visible = not enabled


func interact_label() -> String:
	if building_mode:
		return _builder.status_text()
	return _interact_label


func _on_died() -> void:
	building_mode = false
	_builder.set_active(false)
	visible = false
	collision_layer = 0
	collision_mask = 0


func _on_respawned() -> void:
	visible = true
	collision_layer = 2
	collision_mask = 1 | 4 | 8 | 32
	global_position = Landscape.seat(Vector3(0, 0, 6), 0.2)
	velocity = Vector3.ZERO
	look_pitch = 0.0
	_camera.rotation.x = 0.0
	sync_mouse_mode()


func _sync_health(current: float, maximum: float) -> void:
	var health := get_node_or_null("Health") as Health
	if health:
		health.max_health = maximum
		health.current = current
		health.dead = current <= 0.0


func _apply_look_settings() -> void:
	if _camera:
		_camera.fov = GameSettings.fov


func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless"
