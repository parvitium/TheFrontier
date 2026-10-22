class_name Economy
extends RefCounted


static func empty_wallet() -> Dictionary:
	return {Ids.SCRAP: 0, Ids.CRYSTAL: 0}


static func normalize(wallet: Dictionary) -> Dictionary:
	var out := empty_wallet()
	out[Ids.SCRAP] = int(wallet.get(Ids.SCRAP, 0))
	out[Ids.CRYSTAL] = int(wallet.get(Ids.CRYSTAL, 0))
	return out


static func can_afford(wallet: Dictionary, cost: Dictionary) -> bool:
	var have := normalize(wallet)
	var need := normalize(cost)
	return have[Ids.SCRAP] >= need[Ids.SCRAP] and have[Ids.CRYSTAL] >= need[Ids.CRYSTAL]


static func spend(wallet: Dictionary, cost: Dictionary) -> Dictionary:
	if not can_afford(wallet, cost):
		return normalize(wallet)
	var next := normalize(wallet)
	var need := normalize(cost)
	next[Ids.SCRAP] -= need[Ids.SCRAP]
	next[Ids.CRYSTAL] -= need[Ids.CRYSTAL]
	return next


static func add(wallet: Dictionary, gain: Dictionary) -> Dictionary:
	var next := normalize(wallet)
	var extra := normalize(gain)
	next[Ids.SCRAP] += extra[Ids.SCRAP]
	next[Ids.CRYSTAL] += extra[Ids.CRYSTAL]
	return next


static func tax(wallet: Dictionary, ratio: float) -> Dictionary:
	var next := normalize(wallet)
	next[Ids.SCRAP] = int(floor(float(next[Ids.SCRAP]) * (1.0 - clampf(ratio, 0.0, 1.0))))
	return next


static func refund(cost: Dictionary, ratio: float) -> Dictionary:
	var need := normalize(cost)
	return {
		Ids.SCRAP: int(floor(float(need[Ids.SCRAP]) * clampf(ratio, 0.0, 1.0))),
		Ids.CRYSTAL: int(floor(float(need[Ids.CRYSTAL]) * clampf(ratio, 0.0, 1.0))),
	}
