class_name BuildingPanel
extends PanelContainer

## Inspect a placed building: turret upgrade tiers + sell with confirm.

signal upgrade_pressed
signal sell_pressed
signal closed

var _title: Label
var _stats: Label
var _upgrade: Button
var _sell: Button
var _hint: Label
var _serial: int = -1
var _confirming: bool = false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", ThemeUtil.panel(Color(0.04, 0.055, 0.07, 0.92)))
	custom_minimum_size = Vector2(360, 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	add_child(col)
	_title = Label.new()
	ThemeUtil.readable_font(_title, Color(0.95, 0.92, 0.78), 18)
	col.add_child(_title)
	_stats = Label.new()
	_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ThemeUtil.readable_font(_stats, Color(0.78, 0.84, 0.8), 14)
	col.add_child(_stats)
	_upgrade = ThemeUtil.menu_button("Upgrade")
	_upgrade.pressed.connect(func() -> void: upgrade_pressed.emit())
	col.add_child(_upgrade)
	_sell = ThemeUtil.menu_button("Sell")
	_sell.pressed.connect(_on_sell_clicked)
	col.add_child(_sell)
	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ThemeUtil.readable_font(_hint, Color(0.7, 0.72, 0.66), 12)
	col.add_child(_hint)


func is_open() -> bool:
	return visible and _serial >= 0


func serial() -> int:
	return _serial


func confirming() -> bool:
	return _confirming


func open(p_serial: int) -> void:
	_serial = p_serial
	_confirming = false
	visible = true
	refresh()


func close_panel() -> void:
	_serial = -1
	_confirming = false
	visible = false
	closed.emit()


func refresh() -> void:
	if _serial < 0 or not Session.state.building_instances.has(_serial):
		close_panel()
		return
	var building_id := Session.state.building_id_of(_serial)
	var def := BuildingCatalog.by_id(building_id)
	var tier := Session.state.building_tier(_serial)
	var name := def.display_name if def else building_id
	if building_id == Ids.TURRET:
		_title.text = "%s  ·  %s" % [name, TurretUpgrades.label_for(tier)]
		var st := TurretUpgrades.stats(tier)
		_stats.text = "HP %d / %d\nDamage %.0f   Range %.0fm   Rate %.1f/s" % [
			round(float(Session.state.building_hp.get(_serial, 0.0))),
			round(float(Session.state.building_max_hp.get(_serial, 0.0))),
			float(st.damage),
			float(st.range),
			1.0 / maxf(float(st.interval), 0.01),
		]
		_upgrade.visible = true
		if TurretUpgrades.can_upgrade(tier):
			var cost := TurretUpgrades.upgrade_cost(tier)
			var nxt := TurretUpgrades.stats(tier + 1)
			_upgrade.text = "Upgrade %s — %s" % [TurretUpgrades.label_for(tier + 1), BuildingValue.cost_text(cost)]
			var afford := Economy.can_afford(Session.state.resources, cost)
			_upgrade.disabled = not afford
			if afford:
				_stats.text += "\nNext: DMG %.0f  RNG %.0fm" % [float(nxt.damage), float(nxt.range)]
			else:
				_upgrade.tooltip_text = "Need %s" % BuildingValue.cost_text(cost)
		else:
			_upgrade.text = "Max tier"
			_upgrade.disabled = true
	else:
		_title.text = name
		_stats.text = "HP %d / %d" % [
			round(float(Session.state.building_hp.get(_serial, 0.0))),
			round(float(Session.state.building_max_hp.get(_serial, 0.0))),
		]
		_upgrade.visible = false
	var refund := BuildingValue.refund_for(building_id, tier)
	if _confirming:
		_sell.text = "Confirm sell — refund %s" % BuildingValue.refund_text(refund)
	else:
		_sell.text = "Sell — refund %s" % BuildingValue.refund_text(refund)
	_hint.text = "RMB close · Hold X %.0fs to sell" % BuildingValue.SELL_HOLD


func _on_sell_clicked() -> void:
	if not _confirming:
		_confirming = true
		refresh()
		return
	sell_pressed.emit()
