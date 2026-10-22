class_name WaveScaler
extends RefCounted

## Pure functions for post-campaign / endless wave growth.


static func scale(wave_number: int) -> WaveSpec:
	var n: int = maxi(wave_number, 1)
	var rushers: int = 4 + n
	var rangers: int = 2 + int(floor(float(n) / 2.0))
	var tanks: int = maxi(1, int(floor(float(n) / 3.0)))
	var over: int = maxi(0, n - 3)
	var hp: float = 1.0 + float(over) * 0.12
	var dmg: float = 1.0 + float(over) * 0.06
	return WaveSpec.make(n, [
		[Ids.RUSHER, rushers, 0.28, false],
		[Ids.RANGER, rangers, 0.42, false],
		[Ids.TANK, tanks, 0.85, true],
	], hp, dmg)


static func expected_count(wave_number: int) -> int:
	return scale(wave_number).total_mobs()
