class_name SurviveOptions
extends RefCounted

## Wave-count choices for Survive setup. 0 means Endless (no wave victory).

const DEFAULT := 10


static func choices() -> Array[int]:
	var out: Array[int] = [10, 20, 30, 50, 0]
	return out


static func button_label(waves: int) -> String:
	if waves <= 0:
		return "Endless\nNo extraction. Waves keep coming."
	if waves == DEFAULT:
		return "%d waves\nA full hold. Standard run." % waves
	return "%d waves" % waves


static func short_label(waves: int) -> String:
	if waves <= 0:
		return "Endless"
	return str(waves)
