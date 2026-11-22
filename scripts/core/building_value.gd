class_name BuildingValue
extends RefCounted

## Place + upgrade spend, and the scrap/crystal refunded on an explicit sell.

const REFUND_RATIO := 0.65
const SELL_HOLD := 0.75


static func spent(building_id: String, tier: int = 0) -> Dictionary:
	var def := BuildingCatalog.by_id(building_id)
	var total := def.cost() if def else Economy.empty_wallet()
	if building_id == Ids.TURRET:
		total = Economy.add(total, TurretUpgrades.spent_upgrades(tier))
	return total


static func refund_for(building_id: String, tier: int = 0) -> Dictionary:
	return Economy.refund(spent(building_id, tier), REFUND_RATIO)


static func refund_text(refund: Dictionary) -> String:
	var scrap := int(refund.get(Ids.SCRAP, 0))
	var crystal := int(refund.get(Ids.CRYSTAL, 0))
	if crystal > 0:
		return "%d scrap, %d crystal" % [scrap, crystal]
	return "%d scrap" % scrap


static func cost_text(cost: Dictionary) -> String:
	return refund_text(cost)
