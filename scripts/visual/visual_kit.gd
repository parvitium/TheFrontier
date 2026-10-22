class_name VisualKit
extends RefCounted

const SLOTS := {
	"core_engine": "res://assets/models/core_engine.glb",
	"building_wall": "res://assets/models/wall.glb",
	"building_turret": "res://assets/models/turret.glb",
	"building_trap": "res://assets/models/trap.glb",
	"building_repair_beacon": "res://assets/models/repair_beacon.glb",
	"building_escape_ship": "res://assets/models/escape_ship.glb",
	"mob_rusher": "res://assets/models/mob_rusher.glb",
	"mob_ranger": "res://assets/models/mob_ranger.glb",
	"mob_tank": "res://assets/models/mob_tank.glb",
	"pulse_rifle": "res://assets/models/pulse_rifle.glb",
	"scatter_cannon": "res://assets/models/scatter_cannon.glb",
	"resource_scrap": "res://assets/models/scrap.glb",
	"resource_crystal": "res://assets/models/crystal.glb",
	"signal_relic": "res://assets/models/relic.glb",
	"rock_a": "res://assets/models/rock_a.glb",
	"rock_b": "res://assets/models/rock_b.glb",
	"rock_c": "res://assets/models/rock_c.glb",
	"storage_tank": "res://assets/models/storage_tank.glb",
	"title_emblem": "res://assets/models/title_emblem.glb",
}


static func path_for(slot: String) -> String:
	return str(SLOTS.get(slot, ""))


static func has_slot(slot: String) -> bool:
	var path := path_for(slot)
	return path != "" and ResourceLoader.exists(path)


static func instance(slot: String) -> Node3D:
	var built := KitFactory.build(slot)
	if built:
		return built
	var path := path_for(slot)
	if path == "" or not ResourceLoader.exists(path):
		return null
	var packed := load(path)
	if packed is PackedScene:
		var node := (packed as PackedScene).instantiate()
		if node is Node3D:
			_remap_materials(node)
			return node
	return null


static func fill(parent: Node3D, slot: String, extra_scale: Vector3 = Vector3.ONE) -> Node3D:
	var inst := instance(slot)
	if inst == null:
		return null
	inst.name = "Kit"
	if extra_scale != Vector3.ONE:
		inst.scale = extra_scale
	parent.add_child(inst)
	play_anim(inst, "walk")
	return inst


static func find_node(root: Node, node_name: String) -> Node3D:
	if root == null:
		return null
	if root.name == node_name and root is Node3D:
		return root as Node3D
	var found := root.find_child(node_name, true, false)
	if found is Node3D:
		return found as Node3D
	return null


static func play_anim(root: Node, prefer: String = "walk") -> void:
	if root == null:
		return
	var ap := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null:
		return
	var names := ap.get_animation_list()
	for anim_name in names:
		if prefer in String(anim_name).to_lower():
			ap.play(anim_name)
			return
	if names.size() > 0:
		ap.play(names[0])


static func _remap_materials(root: Node) -> void:
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var src: Material = mi.material_override
		if src == null:
			src = mi.get_active_material(0)
		if src == null and mi.mesh.get_surface_count() > 0:
			src = mi.mesh.surface_get_material(0)
		var mat_name := ""
		if src:
			mat_name = src.resource_name
		if mat_name == "":
			mat_name = mi.name
		mi.material_override = PbrLibrary.by_kit_name(mat_name)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
