class_name WaveSpec
extends RefCounted

class Entry:
	extends RefCounted
	var mob_id: String
	var count: int
	var spawn_delay: float
	var prefer_core: bool

	func _init(p_mob_id: String = Ids.RUSHER, p_count: int = 1, p_delay: float = 0.35, p_prefer_core: bool = false) -> void:
		mob_id = p_mob_id
		count = p_count
		spawn_delay = p_delay
		prefer_core = p_prefer_core


var wave_number: int = 1
var entries: Array[Entry] = []
var hp_multiplier: float = 1.0
var damage_multiplier: float = 1.0


func total_mobs() -> int:
	var n := 0
	for entry in entries:
		n += entry.count
	return n


static func make(number: int, raw_entries: Array, hp_mult: float = 1.0, dmg_mult: float = 1.0) -> WaveSpec:
	var spec := WaveSpec.new()
	spec.wave_number = number
	spec.hp_multiplier = hp_mult
	spec.damage_multiplier = dmg_mult
	for raw in raw_entries:
		var entry := Entry.new(String(raw[0]), int(raw[1]), float(raw[2]) if raw.size() > 2 else 0.35, bool(raw[3]) if raw.size() > 3 else false)
		spec.entries.append(entry)
	return spec
