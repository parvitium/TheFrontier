extends Node

## Usage: godot --headless --path . --scene res://tools/bake_landscape.tscn


func _ready() -> void:
	print("Baking landscape meshes to res://assets/baked")
	Landscape.bake_to_disk()
	print("BAKE DONE")
	get_tree().quit(0)
