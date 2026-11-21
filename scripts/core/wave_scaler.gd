class_name WaveScaler
extends RefCounted

## Pure functions for post-campaign / endless wave growth.
## Slow linear ramp so a 10–50 wave hold stays playable.


static func scale(wave_number: int) -> WaveSpec:
	var n: int = maxi(wave_number, 1)
	var rushers: int = 5 + int(floor(float(n) * 0.40))
	var rangers: int = 2 + int(floor(float(n) * 0.28))
	var tanks: int = 1 + int(floor(float(n - 1) / 5.0))
	var over: int = maxi(0, n - 3)
	var hp: float = 1.0 + float(over) * 0.05
	var dmg: float = 1.0 + float(over) * 0.025
	var rush_delay: float = maxf(0.20, 0.36 - float(over) * 0.004)
	return WaveSpec.make(n, [
		[Ids.RUSHER, rushers, rush_delay, false],
		[Ids.RANGER, rangers, 0.42, false],
		[Ids.TANK, tanks, 0.85, true],
	], hp, dmg)


static func expected_count(wave_number: int) -> int:
	return scale(wave_number).total_mobs()
