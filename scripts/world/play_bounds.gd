class_name PlayBounds
extends RefCounted

## Invisible walls at the playfield collider edge, plus a kill-plane so
## players and mobs that still slip off snap back instead of falling forever.

const HALF := 35.0
const WALL_THICK := 2.4
const WALL_HEIGHT := 28.0
const KILL_Y := -8.0
const PLAYER_SPAWN := Vector3(0.0, 0.0, 6.0)


static func install(parent: Node3D) -> void:
	if parent == null or parent.get_node_or_null("Bounds") != null:
		return
	var holder := Node3D.new()
	holder.name = "Bounds"
	parent.add_child(holder)
	var y := WALL_HEIGHT * 0.5 - 2.0
	_wall(holder, "North", Vector3(0.0, y, HALF + WALL_THICK * 0.5), Vector3(HALF * 2.0 + WALL_THICK * 2.0, WALL_HEIGHT, WALL_THICK))
	_wall(holder, "South", Vector3(0.0, y, -(HALF + WALL_THICK * 0.5)), Vector3(HALF * 2.0 + WALL_THICK * 2.0, WALL_HEIGHT, WALL_THICK))
	_wall(holder, "East", Vector3(HALF + WALL_THICK * 0.5, y, 0.0), Vector3(WALL_THICK, WALL_HEIGHT, HALF * 2.0))
	_wall(holder, "West", Vector3(-(HALF + WALL_THICK * 0.5), y, 0.0), Vector3(WALL_THICK, WALL_HEIGHT, HALF * 2.0))


static func is_fallen(pos: Vector3) -> bool:
	return pos.y < KILL_Y


static func is_outside(pos: Vector3) -> bool:
	return absf(pos.x) > HALF + 0.6 or absf(pos.z) > HALF + 0.6


static func needs_recovery(pos: Vector3) -> bool:
	return is_fallen(pos) or (is_outside(pos) and pos.y < Landscape.height_at(clampf(pos.x, -HALF, HALF), clampf(pos.z, -HALF, HALF)) - 2.0)


static func player_safe_pos() -> Vector3:
	return Landscape.seat(PLAYER_SPAWN, 0.2)


static func clamp_xz(pos: Vector3) -> Vector3:
	var x := clampf(pos.x, -HALF + 1.0, HALF - 1.0)
	var z := clampf(pos.z, -HALF + 1.0, HALF - 1.0)
	return Landscape.seat(Vector3(x, 0.0, z), 0.2)


static func _wall(parent: Node3D, wall_name: String, at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = wall_name
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = at
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	parent.add_child(body)
