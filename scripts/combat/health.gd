class_name Health
extends Node

signal damaged(amount: float, source: Node)
signal died(source: Node)

@export var max_health: float = 100.0
var current: float = 100.0
var dead: bool = false
var team: String = ""


func _ready() -> void:
	current = max_health


func configure(hp: float, p_team: String = "") -> void:
	max_health = hp
	current = hp
	dead = false
	team = p_team


func apply(amount: float, source: Node = null) -> void:
	if dead or amount <= 0.0:
		return
	current = max(0.0, current - amount)
	damaged.emit(amount, source)
	if current <= 0.0:
		dead = true
		died.emit(source)


func heal(amount: float) -> void:
	if dead or amount <= 0.0:
		return
	current = min(max_health, current + amount)
