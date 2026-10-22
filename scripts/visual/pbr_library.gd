class_name PbrLibrary
extends RefCounted

const METAL_DIR := "res://assets/textures/metal_plate"
const RUST_DIR := "res://assets/textures/rusty_metal_02"
const CONCRETE_DIR := "res://assets/textures/concrete_floor_02"
const ROCK_DIR := "res://assets/textures/rock_face"
const SAND_DIR := "res://assets/textures/sand_01"
const DIRT_DIR := "res://assets/textures/brown_mud_03"
const TERRAIN_SHADER := "res://assets/shaders/terrain_blend.gdshader"

static var _cache: Dictionary = {}


static func metal(tint: Color = Color(1, 1, 1), metallic: float = 0.82, roughness_mul: float = 1.0, world_triplanar: bool = true) -> StandardMaterial3D:
	return _pbr("metal", METAL_DIR, tint, metallic, roughness_mul, true, 0.35, world_triplanar)


static func rust(tint: Color = Color(1, 1, 1)) -> StandardMaterial3D:
	return _pbr("rust", RUST_DIR, tint, 0.55, 1.05, true)


static func concrete(tint: Color = Color(1, 1, 1)) -> StandardMaterial3D:
	return _pbr("concrete", CONCRETE_DIR, tint, 0.04, 1.0, false)


static func rock(tint: Color = Color(1, 1, 1)) -> StandardMaterial3D:
	return _pbr("rock", ROCK_DIR, tint, 0.02, 1.05, false, 0.08)


static func sand(tint: Color = Color(1, 1, 1)) -> StandardMaterial3D:
	return _pbr("sand", SAND_DIR, tint, 0.0, 1.1, false, 0.16)


static func dirt(tint: Color = Color(1, 1, 1)) -> StandardMaterial3D:
	return _pbr("dirt", DIRT_DIR, tint, 0.0, 1.05, false, 0.14)


static func emissive(color: Color, energy: float = 4.0) -> StandardMaterial3D:
	var key := "emit_%s_%.1f" % [color.to_html(false), energy]
	if _cache.has(key):
		return _cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	mat.metallic = 0.15
	mat.roughness = 0.22
	_cache[key] = mat
	return mat


static func glass(color: Color = Color(0.35, 0.7, 0.9, 0.35)) -> StandardMaterial3D:
	if _cache.has("glass"):
		return _cache["glass"]
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.metallic = 0.1
	mat.roughness = 0.08
	mat.emission_enabled = true
	mat.emission = Color(0.25, 0.65, 0.9)
	mat.emission_energy_multiplier = 0.6
	_cache["glass"] = mat
	return mat


static func flesh(color: Color) -> StandardMaterial3D:
	var mat := rust(color)
	mat.metallic = 0.08
	mat.roughness = 0.48
	mat.rim_enabled = true
	mat.rim = 0.25
	mat.rim_tint = 0.6
	return mat


static func terrain() -> ShaderMaterial:
	if _cache.has("terrain"):
		return _cache["terrain"]
	var mat := ShaderMaterial.new()
	if ResourceLoader.exists(TERRAIN_SHADER):
		mat.shader = load(TERRAIN_SHADER)
		_bind_tri(mat, "sand", SAND_DIR)
		_bind_tri(mat, "dirt", DIRT_DIR)
		_bind_tri(mat, "rock", ROCK_DIR)
		mat.set_shader_parameter("uv_scale", 0.11)
		mat.set_shader_parameter("rock_slope", 0.4)
	_cache["terrain"] = mat
	return mat


static func by_kit_name(name: String) -> Material:
	var n: String = name.to_lower()
	if "emissiveamber" in n or "emit_a" in n:
		return emissive(Color(1.0, 0.62, 0.18), 6.5)
	if "emissivecyan" in n or "emit_c" in n:
		return emissive(Color(0.25, 0.9, 1.0), 5.5)
	if "emissivered" in n or "emit_r" in n:
		return emissive(Color(1.0, 0.18, 0.1), 5.0)
	if "glass" in n:
		return glass()
	if "rust" in n:
		return rust()
	if "concrete" in n:
		return concrete()
	if "rock" in n or "sand" in n:
		return rock() if "rock" in n else sand()
	if "flesh" in n:
		return flesh(Color(0.55, 0.16, 0.12))
	if "shell" in n:
		return metal(Color(0.55, 0.58, 0.6), 0.45, 1.1)
	if "rubber" in n or "dark" in n:
		return metal(Color(0.18, 0.19, 0.2), 0.7, 0.9)
	if "paint" in n:
		return metal(Color(0.35, 0.4, 0.44), 0.6, 0.95)
	if "metal" in n:
		return metal()
	return metal(Color(0.7, 0.72, 0.74), 0.4, 1.0)


static func _pbr(key: String, dir: String, tint: Color, metallic: float, roughness_mul: float, is_metal: bool, uv_scale: float = 0.35, world_triplanar: bool = true) -> StandardMaterial3D:
	var cache_key := "%s_%s_%.2f_%s" % [key, tint.to_html(false), metallic, str(world_triplanar)]
	if _cache.has(cache_key):
		return _cache[cache_key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.metallic = metallic
	mat.roughness = clampf(0.45 * roughness_mul, 0.05, 1.0)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.uv1_scale = Vector3(uv_scale, uv_scale, uv_scale)
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = world_triplanar
	mat.uv1_triplanar_sharpness = 4.0
	var albedo := _tex(dir, "diff")
	if albedo:
		mat.albedo_texture = albedo
	var nor := _tex(dir, "nor_gl")
	if nor:
		mat.normal_enabled = true
		mat.normal_texture = nor
		mat.normal_scale = 0.9
	var rough := _tex(dir, "rough")
	if rough:
		mat.roughness_texture = rough
		mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	var metal_tex := _tex(dir, "metal")
	if metal_tex and is_metal:
		mat.metallic_texture = metal_tex
		mat.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	var ao := _tex(dir, "ao")
	if ao:
		mat.ao_enabled = true
		mat.ao_texture = ao
		mat.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		mat.ao_light_affect = 0.6
	_cache[cache_key] = mat
	return mat


static func _tex(dir: String, stem: String) -> Texture2D:
	for ext in [".jpg", ".png"]:
		var path := "%s/%s%s" % [dir, stem, ext]
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return null


static func _bind_tri(mat: ShaderMaterial, prefix: String, dir: String) -> void:
	var albedo := _tex(dir, "diff")
	var nor := _tex(dir, "nor_gl")
	var rough := _tex(dir, "rough")
	if albedo:
		mat.set_shader_parameter("%s_albedo" % prefix, albedo)
	if nor:
		mat.set_shader_parameter("%s_normal" % prefix, nor)
	if rough:
		mat.set_shader_parameter("%s_rough" % prefix, rough)
