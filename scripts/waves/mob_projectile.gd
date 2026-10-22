class_name MobProjectile
extends Area3D

var direction: Vector3 = Vector3.FORWARD
var speed: float = 18.0
var damage: float = 7.0
var life: float = 3.0


func _ready() -> void:
	collision_layer = 16
	collision_mask = 1 | 2 | 8 | 32
	var visual := Greybox.sphere(0.12, PbrLibrary.emissive(Color(0.85, 0.3, 1.0), 8.0), "Bolt")
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
	Session.cmd_resolve_hit("mob", body, damage)
	queue_free()
