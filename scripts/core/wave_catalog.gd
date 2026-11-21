class_name WaveCatalog
extends RefCounted

## Authored opening waves. After these, WaveScaler continues the ramp for
## Survive (10/20/30/50/Endless) and Endless mode.


static func campaign_waves() -> Array[WaveSpec]:
	var waves: Array[WaveSpec] = []
	waves.append(WaveSpec.make(1, [
		[Ids.RUSHER, 6, 0.45, false],
	]))
	waves.append(WaveSpec.make(2, [
		[Ids.RUSHER, 5, 0.40, false],
		[Ids.RANGER, 3, 0.70, false],
	]))
	waves.append(WaveSpec.make(3, [
		[Ids.RUSHER, 4, 0.35, false],
		[Ids.RANGER, 3, 0.55, false],
		[Ids.TANK, 2, 1.10, true],
	]))
	for n in range(4, 11):
		waves.append(WaveScaler.scale(n))
	return waves


static func wave_for(index: int, _endless: bool = true) -> WaveSpec:
	var authored := campaign_waves()
	if index >= 1 and index <= authored.size():
		return authored[index - 1]
	return WaveScaler.scale(maxi(index, 1))
