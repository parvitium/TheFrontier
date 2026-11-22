class_name MobStuck
extends RefCounted

## Detects a mob that is not engaged and has not displaced for STUCK_SECONDS.
## Recovery is re-path, then nudge, then respawn onto a spawn ring.

const STUCK_SECONDS := 2.0
const MOVE_EPSILON := 0.35
const NUDGE_DISTANCE := 1.4
const PLAYER_RADIUS := 0.36
const CORE_RADIUS := 1.55
const BUILDING_RADIUS := 0.95

enum Action { NONE, REPATH, NUDGE, RESPAWN }


static func melee_reach(def: MobDef, target: Node = null) -> float:
	var body_r := 0.4
	var range_m := 1.6
	if def:
		body_r = def.radius
		range_m = def.melee_range
	return range_m + body_r + target_radius(target) + 0.2


static func target_radius(target: Node) -> float:
	if target == null:
		return 0.0
	if target.is_in_group("core"):
		return CORE_RADIUS
	if target.is_in_group("player"):
		return PLAYER_RADIUS
	if target is BuildingBase:
		return BUILDING_RADIUS
	return 0.0


static func is_engaged(dist: float, def: MobDef, target: Node = null) -> bool:
	if def == null:
		return false
	if dist <= melee_reach(def, target):
		return true
	if def.ranged_damage > 0.0 and dist <= def.ranged_range:
		return true
	return false


static func horizontal_distance(a: Vector3, b: Vector3) -> float:
	var dx: float = a.x - b.x
	var dz: float = a.z - b.z
	return sqrt(dx * dx + dz * dz)


static func update(idle: float, anchor: Vector3, current: Vector3, delta: float, engaged: bool) -> Dictionary:
	if engaged:
		return {idle = 0.0, anchor = current, moved = true}
	if horizontal_distance(anchor, current) >= MOVE_EPSILON:
		return {idle = 0.0, anchor = current, moved = true}
	return {idle = idle + delta, anchor = anchor, moved = false}


static func choose_action(idle: float, recoveries: int) -> int:
	if idle < STUCK_SECONDS:
		return Action.NONE
	if recoveries <= 0:
		return Action.REPATH
	if recoveries == 1:
		return Action.NUDGE
	return Action.RESPAWN


static func nudge_offsets(forward: Vector3) -> Array[Vector3]:
	var f := Vector3(forward.x, 0.0, forward.z)
	if f.length() < 0.01:
		f = Vector3(1.0, 0.0, 0.0)
	else:
		f = f.normalized()
	var right := Vector3(-f.z, 0.0, f.x)
	var out: Array[Vector3] = [
		right * NUDGE_DISTANCE,
		-right * NUDGE_DISTANCE,
		f * NUDGE_DISTANCE,
		-f * NUDGE_DISTANCE,
		(right + f).normalized() * NUDGE_DISTANCE,
	]
	return out
