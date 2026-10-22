class_name MobProjectile
extends Area3D

var direction: Vector3 = Vector3.FORWARD
var speed: float = 18.0
var damage: float = 7.0
var life: float = 3.0


func _ready() -> void:
	collision_layer = 16
	collision_mask = 1 | 2 | 8 | 32
	var visual := Greybox.sphere(0.12, Greybox.material(Color(0.85, 0.3, 1.0), Color(0.8, 0.3, 1.0), 3.0, 0.0, 0.2), "Bolt")
	add_child(visual)
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.14
	col.shape = shape
	add_child(col)
	body_entered.connect(_on_body)


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	life -= delta
	if life <= 0.0:
		queue_free()


func _on_body(body: Node) -> void:
	if body.is_in_group("mobs"):
		return
	if body.is_in_group("player"):
		Session.cmd_damage_player(damage)
	elif body.is_in_group("core"):
		Session.cmd_damage_core(damage)
	else:
		var health := body.get_node_or_null("Health") as Health
		if health:
			health.apply(damage, self)
	queue_free()
