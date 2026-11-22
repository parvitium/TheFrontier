class_name MobProjectile
extends Area3D

var direction: Vector3 = Vector3.FORWARD
var speed: float = 18.0
var damage: float = 7.0
var life: float = 3.0
var shot_vfx: String = "spell"
var _spent: bool = false


func _ready() -> void:
	collision_layer = 16
	collision_mask = 1 | 2 | 8 | 32
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.14
	col.shape = shape
	add_child(col)
	body_entered.connect(_on_body)
	CombatFx.dress_projectile(self, shot_vfx)


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	if direction.length() > 0.05 and absf(direction.normalized().dot(Vector3.UP)) < 0.995:
		look_at(global_position + direction, Vector3.UP)
	life -= delta
	if life <= 0.0:
		_expire()


func _on_body(body: Node) -> void:
	if body.is_in_group("mobs"):
		return
	Session.cmd_resolve_hit("mob", body, damage)
	var host: Node = get_tree().current_scene
	if host == null:
		host = self
	CombatFx.impact(host, global_position, FxSurface.shot_color(shot_vfx), body, -direction)
	CombatFx.projectile_burst(host, global_position, shot_vfx)
	_expire()


func _expire() -> void:
	if _spent:
		return
	_spent = true
	CombatFx.release_projectile(self)
	queue_free()
