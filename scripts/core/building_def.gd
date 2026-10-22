class_name BuildingDef
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var scrap_cost: int = 0
@export var crystal_cost: int = 0
@export var max_health: float = 50.0
@export var footprint: Vector2i = Vector2i.ONE
@export var blocks_navigation: bool = true
@export var buildable_in_all_modes: bool = true
@export_multiline var description: String = ""
@export var color: Color = Color(0.55, 0.62, 0.7)


func cost() -> Dictionary:
	return {Ids.SCRAP: scrap_cost, Ids.CRYSTAL: crystal_cost}
