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
var _cross: ColorRect
var _banner_time: float = 0.0


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_phase = _label(root, Vector2(20, 16), 20, Color(0.85, 0.9, 0.88))
	_objective = _label(root, Vector2(20, 44), 16, Color(0.7, 0.78, 0.74))
	_core = _label(root, Vector2(20, 72), 16, Color(1.0, 0.78, 0.32))
	_hp = _label(root, Vector2(20, 96), 16, Color(0.85, 0.35, 0.32))
	_res = _label(root, Vector2(20, 120), 16, Color(0.45, 0.85, 0.75))
	_ammo = _label(root, Vector2(20, 144), 16, Color(0.8, 0.82, 0.7))
	_hint = _label(root, Vector2(20, 640), 15, Color(0.78, 0.8, 0.72))
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_top = -48
	_hint.offset_bottom = -20
	_banner = _label(root, Vector2(0, 80), 22, Color(0.95, 0.92, 0.7))
	_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_banner.offset_left = 80
	_banner.offset_right = -80
	_banner.offset_top = 86
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cross = ColorRect.new()
	_cross.color = Color(0.9, 0.95, 0.9, 0.85)
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
	_banner.visible = _banner_time > 0.0
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
	var player := get_tree().get_first_node_in_group("player") as PlayerController
	if player and player._weapons:
		_ammo.text = "%s  %s" % [player._weapons.current_def().display_name, player._weapons.ammo_text()]
		_hint.text = player.interact_label()
	else:
		_ammo.text = ""
		_hint.text = ""


func _objective_text(mode: GameModeDef, state: GameState) -> String:
	match mode.kind:
		GameModeDef.Kind.SURVIVE:
			return "Survive %d waves  (%d done)" % [mode.survive_waves, state.waves_completed]
		GameModeDef.Kind.GATHER:
			return "Recover relics  %d / %d" % [state.relics_collected, mode.gather_count]
		GameModeDef.Kind.ESCAPE:
			return "Assemble the escape ship  (%d scrap, %d crystal)" % [BuildingCatalog.by_id(Ids.ESCAPE_SHIP).scrap_cost, BuildingCatalog.by_id(Ids.ESCAPE_SHIP).crystal_cost]
		GameModeDef.Kind.ENDLESS:
			return "Endless  ·  waves cleared %d" % state.waves_completed
	return ""


func _on_banner(text: String) -> void:
	_banner.text = text
	_banner_time = 3.2


func _label(parent: Control, pos: Vector2, size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.add_theme_font_size_override("font_size", size)
	ThemeUtil.font_color(label, color)
	parent.add_child(label)
	return label
