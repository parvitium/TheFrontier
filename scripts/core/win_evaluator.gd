class_name WinEvaluator
extends RefCounted

enum Outcome { NONE, VICTORY, DEFEAT }


static func evaluate(state: GameState, mode: GameModeDef) -> Outcome:
	if state == null or mode == null:
		return Outcome.NONE
	if state.core_health <= 0.0:
		return Outcome.DEFEAT
	match mode.kind:
		GameModeDef.Kind.SURVIVE:
			if mode.survive_waves > 0 and state.waves_completed >= mode.survive_waves:
				return Outcome.VICTORY
			if mode.survive_seconds > 0.0 and state.elapsed_time >= mode.survive_seconds:
				return Outcome.VICTORY
		GameModeDef.Kind.GATHER:
			if mode.gather_count > 0 and state.relics_collected >= mode.gather_count:
				return Outcome.VICTORY
		GameModeDef.Kind.ESCAPE:
			if state.escape_ship_built:
				return Outcome.VICTORY
		GameModeDef.Kind.ENDLESS:
			pass
	return Outcome.NONE
