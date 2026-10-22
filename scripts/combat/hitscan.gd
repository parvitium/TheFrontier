class_name Hitscan
extends RefCounted

const HOSTILE_MASK := 1 | 4 | 8


static func fire(space: World3D, origin: Vector3, direction: Vector3, distance: float, exclude: Array[RID], damage: float, source: Node, spread_deg: float = 0.0) -> Dictionary:
	var dir := direction.normalized()
	if spread_deg > 0.0:
		dir = _spread(dir, spread_deg)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * distance)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = exclude
	query.collision_mask = HOSTILE_MASK
	var hit := space.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {hit = false, dir = dir}
	_apply_damage(hit.collider, damage, source)
	return {hit = true, position = hit.position, collider = hit.collider, dir = dir}


static func _apply_damage(collider: Object, damage: float, source: Node) -> void:
	if collider == null or not collider is Node:
		return
	var health := (collider as Node).get_node_or_null("Health") as Health
	if health:
		health.apply(damage, source)


static func _spread(dir: Vector3, degrees: float) -> Vector3:
	var rad := deg_to_rad(degrees)
	var up := Vector3.UP
	if absf(dir.dot(up)) > 0.995:
		up = Vector3.RIGHT
	var basis := Basis.looking_at(dir, up)
	var yaw := randf_range(-rad, rad)
	var pitch := randf_range(-rad, rad)
	return (basis * Vector3(sin(yaw), sin(pitch), -cos(yaw)).normalized()).normalized()
