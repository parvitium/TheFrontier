class_name GameModeDef
extends Resource

enum Kind { SURVIVE, GATHER, ESCAPE, ENDLESS }

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var kind: Kind = Kind.SURVIVE
@export var survive_waves: int = 0
@export var survive_seconds: float = 0.0
@export var gather_count: int = 0
@export var relics_on_map: int = 0
@export var escape_building_id: String = Ids.ESCAPE_SHIP
@export var starting_scrap: int = 40
@export var starting_crystal: int = 15
@export var rest_seconds: float = 25.0
@export var core_max_health: float = 400.0
@export var player_max_health: float = 100.0
@export var player_respawn_seconds: float = 5.0
@export var death_scrap_tax_ratio: float = 0.15
@export var first_rest_seconds: float = 20.0
