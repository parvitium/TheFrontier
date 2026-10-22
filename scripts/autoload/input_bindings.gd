extends Node


func _enter_tree() -> void:
	_key("move_forward", KEY_W)
	_key("move_back", KEY_S)
	_key("move_left", KEY_A)
	_key("move_right", KEY_D)
	_key("jump", KEY_SPACE)
	_key("sprint", KEY_SHIFT)
	_key("reload", KEY_R)
	_key("interact", KEY_E)
	_key("build_mode", KEY_B)
	_key("dismantle", KEY_X)
	_key("weapon_1", KEY_1)
	_key("weapon_2", KEY_2)
	_key("build_1", KEY_3)
	_key("build_2", KEY_4)
	_key("build_3", KEY_5)
	_key("build_4", KEY_6)
	_key("build_5", KEY_7)
	_key("pause", KEY_ESCAPE)
	_mouse("fire", MOUSE_BUTTON_LEFT)
	_mouse("alt_fire", MOUSE_BUTTON_RIGHT)
	_mouse("cycle_build_next", MOUSE_BUTTON_WHEEL_DOWN)
	_mouse("cycle_build_prev", MOUSE_BUTTON_WHEEL_UP)


func _key(action: String, keycode: Key) -> void:
	_ensure(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	if not _has_event(action, event):
		InputMap.action_add_event(action, event)


func _mouse(action: String, button: MouseButton) -> void:
	_ensure(action)
	var event := InputEventMouseButton.new()
	event.button_index = button
	if not _has_event(action, event):
		InputMap.action_add_event(action, event)


func _ensure(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)


func _has_event(action: String, event: InputEvent) -> bool:
	for existing in InputMap.action_get_events(action):
		if existing.as_text() == event.as_text():
			return true
	return false
