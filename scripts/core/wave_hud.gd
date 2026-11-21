class_name WaveHud
extends RefCounted

## Pure HUD copy for wave index / goal so tests can assert the X/Y vs Endless labels.


static func is_endless_goal(kind: int, survive_waves: int) -> bool:
	if kind == GameModeDef.Kind.ENDLESS:
		return true
	return kind == GameModeDef.Kind.SURVIVE and survive_waves <= 0


static func index_text(index: int, goal: int, endless: bool) -> String:
	if endless:
		return "%d  Endless" % index
	if goal > 0:
		return "%d/%d" % [index, goal]
	return str(index)


static func rest_line(rest_remaining: float, next_index: int, goal: int, endless: bool) -> String:
	return "REST  %.0fs   ·  next wave %s" % [rest_remaining, index_text(next_index, goal, endless)]


static func wave_line(index: int, goal: int, endless: bool, hostiles: int) -> String:
	return "WAVE %s   ·  hostiles %d" % [index_text(index, goal, endless), hostiles]


static func objective_survive(goal: int, completed: int) -> String:
	if goal <= 0:
		return "Survive Endless  (%d cleared)" % completed
	return "Survive %d waves  (%d done)" % [goal, completed]
