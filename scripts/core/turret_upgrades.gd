class_name TurretUpgrades
extends RefCounted

## Tiered Auto-Turret stats. Tier 0 is the placed turret; 1 and 2 are upgrades.

const MAX_TIER := 2

const TIERS: Array[Dictionary] = [
	{damage = 15.0, interval = 0.4, range = 18.0, scrap = 0, crystal = 0, label = "Mk I"},
	{damage = 22.0, interval = 0.32, range = 21.0, scrap = 20, crystal = 5, label = "Mk II"},
	{damage = 32.0, interval = 0.24, range = 24.5, scrap = 35, crystal = 8, label = "Mk III"},
]


static func clamp_tier(tier: int) -> int:
	return clampi(tier, 0, MAX_TIER)


static func stats(tier: int) -> Dictionary:
	return TIERS[clamp_tier(tier)]


static func label_for(tier: int) -> String:
	return str(stats(tier).get("label", "Mk I"))


static func can_upgrade(tier: int) -> bool:
	return clamp_tier(tier) < MAX_TIER


static func upgrade_cost(from_tier: int) -> Dictionary:
	if not can_upgrade(from_tier):
		return Economy.empty_wallet()
	var nxt: Dictionary = TIERS[from_tier + 1]
	return {Ids.SCRAP: int(nxt.scrap), Ids.CRYSTAL: int(nxt.crystal)}


static func spent_upgrades(tier: int) -> Dictionary:
	var out := Economy.empty_wallet()
	var t := 0
	while t < clamp_tier(tier):
		out = Economy.add(out, upgrade_cost(t))
		t += 1
	return out
