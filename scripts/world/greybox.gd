class_name Greybox
extends RefCounted

## Helpers for placeholder meshes. Swap a node's Visual child for a .glb later.


static func material(color: Color, emission: Color = Color.BLACK, emission_energy: float = 0.0, metallic: float = 0.05, roughness: float = 0.72) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	if emission_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = emission_energy
	return mat


static func mesh_instance(mesh: Mesh, mat: Material, name: String = "Mesh") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh
	mi.material_override = mat
	return mi


static func box(size: Vector3, mat: Material, name: String = "Box") -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh_instance(mesh, mat, name)


static func cylinder(radius: float, height: float, mat: Material, name: String = "Cylinder") -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	return mesh_instance(mesh, mat, name)


static func sphere(radius: float, mat: Material, name: String = "Sphere") -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	return mesh_instance(mesh, mat, name)


static func static_box(parent: Node3D, size: Vector3, position: Vector3, mat: Material, name: String, layer: int = 1) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = position
	var visual := Node3D.new()
	visual.name = "Visual"
	visual.set_meta("asset_slot", name.to_snake_case())
	visual.add_child(box(size, mat))
	body.add_child(visual)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	parent.add_child(body)
	return body
