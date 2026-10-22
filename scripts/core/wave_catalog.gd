class_name WaveCatalog
extends RefCounted

## Authored campaign waves. Endless mode continues with WaveScaler after these.


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
	return waves


static func wave_for(index: int, endless: bool) -> WaveSpec:
	var authored := campaign_waves()
	if index >= 1 and index <= authored.size():
		return authored[index - 1]
	if endless:
		return WaveScaler.scale(index)
	return authored[authored.size() - 1]
