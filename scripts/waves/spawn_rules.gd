class_name SpawnRules
extends RefCounted

## Picks a walkable mob spawn: far from the player, off colliding cover, not on a steep wash.

const MAX_SLOPE_DEG := 36.0
const MIN_COVER_CLEARANCE := 2.8
const RING_RADIUS := 30.0
const RING_COUNT := 8
const FALLBACK_RADII: Array[float] = [30.0, 26.0, 22.0, 18.0]


static func ring_points(radius: float = RING_RADIUS, count: int = RING_COUNT) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	for i in count:
		var angle: float = TAU * float(i) / float(count)
		pts.append(Vector3(cos(angle) * radius, 0.0, sin(angle) * radius))
	return pts


static func is_walkable(pos: Vector3, cover: Array[Vector3]) -> bool:
	if Landscape.slope_deg(pos.x, pos.z) > MAX_SLOPE_DEG:
		return false
	for rock in cover:
		if SpawnRules.horizontal_distance(pos, rock) < MIN_COVER_CLEARANCE:
			return false
	return true


static func horizontal_distance(a: Vector3, b: Vector3) -> float:
	var dx: float = a.x - b.x
	var dz: float = a.z - b.z
	return sqrt(dx * dx + dz * dz)


static func score(pos: Vector3, player_pos: Vector3, cover: Array[Vector3]) -> float:
	if not is_walkable(pos, cover):
		return -1.0
	var away: float = horizontal_distance(pos, player_pos)
	var slope_pen: float = Landscape.slope_deg(pos.x, pos.z) * 0.15
	return away - slope_pen


static func pick(candidates: Array[Vector3], player_pos: Vector3, cover: Array[Vector3], cursor: int) -> Vector3:
	var pool: Array[Vector3] = []
	for pos in candidates:
		pool.append(pos)
	if pool.is_empty():
		pool = ring_points()
	var chosen := _pick_from(pool, player_pos, cover, cursor)
	if chosen != Vector3.INF:
		return chosen
	for radius in FALLBACK_RADII:
		chosen = _pick_from(ring_points(radius), player_pos, cover, cursor)
		if chosen != Vector3.INF:
			return chosen
	if pool.is_empty():
		return Vector3(22.0, 0.0, 0.0)
	return pool[cursor % pool.size()]


static func _pick_from(candidates: Array[Vector3], player_pos: Vector3, cover: Array[Vector3], cursor: int) -> Vector3:
	var valid: Array[Vector3] = []
	var scores: Array[float] = []
	for pos in candidates:
		var s: float = score(pos, player_pos, cover)
		if s >= 0.0:
			valid.append(pos)
			scores.append(s)
	if valid.is_empty():
		return Vector3.INF
	var order: Array[int] = []
	for i in valid.size():
		order.append(i)
	var top_n: int = mini(3, order.size())
	for a in top_n:
		var best: int = a
		for b in range(a + 1, order.size()):
			if scores[order[b]] > scores[order[best]]:
				best = b
		var tmp: int = order[a]
		order[a] = order[best]
		order[best] = tmp
	return valid[order[cursor % top_n]]
