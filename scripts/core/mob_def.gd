class_name MobDef
extends Resource

enum TargetBias { CORE, PLAYER, HYBRID }

@export var id: String = ""
@export var display_name: String = ""
@export var max_health: float = 40.0
@export var move_speed: float = 5.0
@export var melee_damage: float = 8.0
@export var melee_range: float = 1.7
@export var melee_interval: float = 0.7
@export var ranged_damage: float = 0.0
@export var ranged_range: float = 0.0
@export var ranged_interval: float = 1.2
@export var preferred_range: float = 0.0
@export var target_bias: TargetBias = TargetBias.HYBRID
@export var aggro_radius: float = 16.0
@export var color: Color = Color(0.8, 0.2, 0.2)
@export var radius: float = 0.45
@export var height: float = 1.6
