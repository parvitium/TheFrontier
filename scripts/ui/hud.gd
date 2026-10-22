class_name Hud
extends CanvasLayer

var _phase: Label
var _objective: Label
var _core: Label
var _hp: Label
var _ammo: Label
var _res: Label
var _hint: Label
var _banner: Label
var _banner_plate: PanelContainer
var _hint_plate: PanelContainer
var _cross: ColorRect
var _banner_time: float = 0.0


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.name = "HudRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var plate := Panel.new()
	plate.position = Vector2(12, 10)
	plate.size = Vector2(420, 168)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_theme_stylebox_override("panel", ThemeUtil.panel(Color(0.03, 0.04, 0.05, 0.55)))
	root.add_child(plate)
	_phase = _label(root, Vector2(20, 16), 20, Color(0.85, 0.9, 0.88))
	_objective = _label(root, Vector2(20, 44), 16, Color(0.7, 0.78, 0.74))
	_core = _label(root, Vector2(20, 72), 16, Color(1.0, 0.78, 0.32))
	_hp = _label(root, Vector2(20, 96), 16, Color(0.85, 0.35, 0.32))
	_res = _label(root, Vector2(20, 120), 16, Color(0.45, 0.85, 0.75))
	_ammo = _label(root, Vector2(20, 144), 16, Color(0.8, 0.82, 0.7))
	_hint_plate = PanelContainer.new()
	_hint_plate.name = "HintPlate"
	_hint_plate.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint_plate.anchor_top = 1.0
	_hint_plate.anchor_bottom = 1.0
	_hint_plate.offset_left = 16
	_hint_plate.offset_right = -16
	_hint_plate.offset_top = -56
	_hint_plate.offset_bottom = -16
	_hint_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_plate.add_theme_stylebox_override("panel", ThemeUtil.overlay_plate(Color(0.03, 0.035, 0.04, 0.78)))
	root.add_child(_hint_plate)
	_hint = Label.new()
	_hint.name = "Hint"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeUtil.readable_font(_hint, Color(0.92, 0.9, 0.82), 15)
	_hint_plate.add_child(_hint)
	var banner_wrap := CenterContainer.new()
	banner_wrap.name = "BannerWrap"
	banner_wrap.set_anchors_preset(Control.PRESET_TOP_WIDE)
	banner_wrap.offset_left = 80
	banner_wrap.offset_right = -80
	banner_wrap.offset_top = 78
	banner_wrap.offset_bottom = 138
	banner_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(banner_wrap)
	_banner_plate = PanelContainer.new()
	_banner_plate.name = "BannerPlate"
	_banner_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_plate.add_theme_stylebox_override("panel", ThemeUtil.overlay_plate(Color(0.025, 0.03, 0.035, 0.84)))
	banner_wrap.add_child(_banner_plate)
	_banner = Label.new()
	_banner.name = "Banner"
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeUtil.readable_font(_banner, Color(0.98, 0.93, 0.72), 22)
	_banner_plate.add_child(_banner)
	var cross_shadow := ColorRect.new()
	cross_shadow.color = Color(0.02, 0.02, 0.03, 0.7)
	cross_shadow.custom_minimum_size = Vector2(8, 8)
	cross_shadow.set_anchors_preset(Control.PRESET_CENTER)
	cross_shadow.offset_left = -4
	cross_shadow.offset_right = 4
	cross_shadow.offset_top = -4
	cross_shadow.offset_bottom = 4
	cross_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cross_shadow)
	_cross = ColorRect.new()
	_cross.color = Color(0.95, 0.96, 0.9, 0.92)
	_cross.custom_minimum_size = Vector2(4, 4)
	_cross.set_anchors_preset(Control.PRESET_CENTER)
	_cross.offset_left = -2
	_cross.offset_right = 2
	_cross.offset_top = -2
	_cross.offset_bottom = 2
	root.add_child(_cross)
	GameBus.banner.connect(_on_banner)
	_on_banner("Fortify the core. Waves will not wait.")


func _process(delta: float) -> void:
	_banner_time = max(0.0, _banner_time - delta)
	var show_banner := _banner_time > 0.0 and _banner.text != ""
	_banner_plate.visible = show_banner
	var state := Session.state
	var mode := Session.mode
	var phase := "REST" if state.phase == GameState.Phase.REST else "WAVE"
	if state.phase == GameState.Phase.VICTORY:
		phase = "VICTORY"
	elif state.phase == GameState.Phase.DEFEAT:
		phase = "DEFEAT"
	if state.phase == GameState.Phase.REST:
		_phase.text = "REST  %.0fs   ·  next wave %d" % [state.rest_remaining, state.wave_index + 1]
	elif state.phase == GameState.Phase.WAVE:
		_phase.text = "WAVE %d   ·  hostiles %d" % [state.wave_index, state.mobs_alive]
	else:
		_phase.text = phase
	_objective.text = _objective_text(mode, state)
	_core.text = "CORE  %d / %d" % [round(state.core_health), round(state.core_max_health)]
	_hp.text = "HULL  %d / %d" % [round(state.player_health), round(state.player_max_health)]
	_res.text = "SCRAP %d    CRYSTAL %d    SCORE %d" % [state.resources.get(Ids.SCRAP, 0), state.resources.get(Ids.CRYSTAL, 0), state.score]
	var wdef := Session.current_weapon_def()
	if wdef:
		_ammo.text = "%s  %s" % [wdef.display_name, Session.ammo_text()]
	else:
		_ammo.text = ""
	var player := get_tree().get_first_node_in_group("player") as PlayerController
	if player:
		_hint.text = player.interact_label()
	else:
		_hint.text = ""
	_hint_plate.visible = _hint.text != ""


func _objective_text(mode: GameModeDef, state: GameState) -> String:
	match mode.kind:
		GameModeDef.Kind.SURVIVE:
			return "Survive %d waves  (%d done)" % [mode.survive_waves, state.waves_completed]
		GameModeDef.Kind.GATHER:
			return "Recover relics  %d / %d" % [state.relics_collected, mode.gather_count]
		GameModeDef.Kind.ESCAPE:
			return "Assemble the escape ship  (%d scrap, %d crystal)" % [BuildingCatalog.by_id(Ids.ESCAPE_SHIP).scrap_cost, BuildingCatalog.by_id(Ids.ESCAPE_SHIP).crystal_cost]
		GameModeDef.Kind.ENDLESS:
			return "Endless  ·  waves cleared %d  ·  relics %d" % [state.waves_completed, state.relics_collected]
	return ""


func _on_banner(text: String) -> void:
	_banner.text = text
	_banner_time = 3.2
	_banner_plate.visible = text != ""


func _label(parent: Control, pos: Vector2, size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	ThemeUtil.readable_font(label, color, size)
	parent.add_child(label)
	return label
