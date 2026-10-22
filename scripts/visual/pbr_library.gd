class_name PbrLibrary
extends RefCounted

const TREAD_DIR := "res://assets/textures/metal_plate"
const METAL_DIR := TREAD_DIR
const PAINT_DIR := "res://assets/textures/rusty_painted_metal"
const CORRUG_DIR := "res://assets/textures/corrugated_iron"
const OXIDE_DIR := "res://assets/textures/rusty_metal_sheet"
const RUST_DIR := "res://assets/textures/rusty_metal_02"
const CONCRETE_DIR := "res://assets/textures/concrete_floor_02"
const ROCK_DIR := "res://assets/textures/rock_face"
const BOULDER_DIR := "res://assets/textures/rock_08"
const SAND_DIR := "res://assets/textures/sand_01"
const DIRT_DIR := "res://assets/textures/brown_mud_03"
const TERRAIN_SHADER := "res://assets/shaders/terrain_blend.gdshader"
const BOULDER_SHADER := "res://assets/shaders/boulder.gdshader"

static var _cache: Dictionary = {}


static func tread(tint: Color = Color(1, 1, 1), metallic: float = 0.84, roughness_mul: float = 1.0, world_triplanar: bool = true) -> StandardMaterial3D:
	return _pbr("tread", TREAD_DIR, tint, metallic, roughness_mul, true, 0.42, world_triplanar)


static func painted(tint: Color = Color(1, 1, 1), metallic: float = 0.42, roughness_mul: float = 1.05, world_triplanar: bool = true) -> StandardMaterial3D:
	return _pbr("paint", PAINT_DIR, tint, metallic, roughness_mul, false, 0.28, world_triplanar)


static func corrugated(tint: Color = Color(1, 1, 1), metallic: float = 0.58, roughness_mul: float = 0.95, world_triplanar: bool = true) -> StandardMaterial3D:
	return _pbr("corrug", CORRUG_DIR, tint, metallic, roughness_mul, false, 0.48, world_triplanar)


static func oxidized(tint: Color = Color(1, 1, 1), metallic: float = 0.72, roughness_mul: float = 1.0, world_triplanar: bool = true) -> StandardMaterial3D:
	return _pbr("oxide", OXIDE_DIR, tint, metallic, roughness_mul, false, 0.30, world_triplanar)


static func metal(tint: Color = Color(1, 1, 1), metallic: float = 0.72, roughness_mul: float = 1.0, world_triplanar: bool = true) -> StandardMaterial3D:
	# Default mill steel is oxidized sheet, not diamond tread.
	return oxidized(tint, metallic, roughness_mul, world_triplanar)


static func rust(tint: Color = Color(1, 1, 1)) -> StandardMaterial3D:
	return _pbr("rust", RUST_DIR, tint, 0.55, 1.05, true)


static func concrete(tint: Color = Color(1, 1, 1)) -> StandardMaterial3D:
	return _pbr("concrete", CONCRETE_DIR, tint, 0.04, 1.0, false)


static func rock(tint: Color = Color(1, 1, 1)) -> StandardMaterial3D:
	return _pbr("rock", ROCK_DIR, tint, 0.0, 1.35, false, 0.08)


static func boulder_pbr(tint: Color = Color(0.94, 0.80, 0.62)) -> StandardMaterial3D:
	var mat := _pbr("boulder", BOULDER_DIR, tint, 0.0, 1.62, false, 0.55)
	mat.metallic = 0.0
	mat.roughness = clampf(mat.roughness, 0.72, 1.0)
	if mat.normal_enabled:
		mat.normal_scale = 0.55
	return mat


static func boulder(tint: Color = Color(0.96, 0.82, 0.64)) -> Material:
	# Triplanar standard material: custom NORMAL_MAP shaders vanish on
	# these generated meshes (poles produce degenerate tangents).
	return boulder_pbr(tint)


static func gun_metal(tint: Color = Color(0.42, 0.44, 0.46), metallic: float = 0.82, roughness_mul: float = 0.72) -> StandardMaterial3D:
	return oxidized(tint, metallic, roughness_mul, false)


static func gun_steel(tint: Color = Color(0.50, 0.52, 0.54)) -> StandardMaterial3D:
	return gun_metal(tint, 0.88, 0.58)


static func gun_dark(tint: Color = Color(0.16, 0.165, 0.17)) -> StandardMaterial3D:
	return gun_metal(tint, 0.86, 0.62)


static func sand(tint: Color = Color(1, 1, 1)) -> StandardMaterial3D:
	return _pbr("sand", SAND_DIR, tint, 0.0, 1.1, false, 0.16)


static func dirt(tint: Color = Color(1, 1, 1)) -> StandardMaterial3D:
	# Packed desert earth: same sand set, warmer/darker tint. Cool mud is unused.
	return sand(Color(0.86, 0.58, 0.32) * tint)


static func polymer(tint: Color = Color(0.14, 0.145, 0.15)) -> StandardMaterial3D:
	var key := "polymer_%s" % tint.to_html(false)
	if _cache.has(key):
		return _cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.metallic = 0.08
	mat.roughness = 0.52
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var grain := _tex(CONCRETE_DIR, "nor_gl")
	if grain:
		mat.normal_enabled = true
		mat.normal_texture = grain
		mat.normal_scale = 0.25
		mat.uv1_scale = Vector3(2.4, 2.4, 2.4)
	_cache[key] = mat
	return mat


static func dust() -> StandardMaterial3D:
	if _cache.has("dust"):
		return _cache["dust"]
	var base := sand(Color(0.92, 0.78, 0.58))
	var fade := base.duplicate() as StandardMaterial3D
	fade.proximity_fade_enabled = true
	fade.proximity_fade_distance = 0.45
	fade.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fade.albedo_color = Color(0.78, 0.62, 0.44, 0.72)
	_cache["dust"] = fade
	return fade


static func scrub() -> StandardMaterial3D:
	if _cache.has("scrub"):
		return _cache["scrub"]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.34, 0.2)
	mat.metallic = 0.0
	mat.roughness = 0.92
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache["scrub"] = mat
	return mat


static func texture_in(dir: String, stem: String) -> Texture2D:
	return _tex(dir, stem)


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
	var key := "glass_%s" % color.to_html(true)
	if _cache.has(key):
		return _cache[key]
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.metallic = 0.12
	mat.roughness = 0.08
	mat.emission_enabled = color.a > 0.2 and color.b > 0.4
	mat.emission = Color(color.r, color.g, color.b)
	mat.emission_energy_multiplier = 0.45 if mat.emission_enabled else 0.0
	_cache[key] = mat
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
		_bind_tri(mat, "dirt", SAND_DIR)
		_bind_tri(mat, "rock", ROCK_DIR)
		mat.set_shader_parameter("uv_scale", 0.16)
		mat.set_shader_parameter("rock_slope", 0.34)
		mat.set_shader_parameter("sand_tint", Vector3(1.12, 0.9, 0.64))
		mat.set_shader_parameter("dirt_tint", Vector3(1.0, 0.7, 0.4))
		mat.set_shader_parameter("rock_tint", Vector3(0.92, 0.74, 0.54))
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
	if "sand" in n:
		return sand(Color(0.82, 0.6, 0.38))
	if "rock" in n:
		return rock()
	if "flesh" in n:
		return flesh(Color(0.55, 0.16, 0.12))
	if "shell" in n:
		return oxidized(Color(0.62, 0.58, 0.52), 0.48, 1.08)
	if "gunpolymer" in n:
		return polymer(Color(0.12, 0.125, 0.13))
	if "gunsteel" in n:
		return gun_steel()
	if "gundark" in n:
		return gun_dark()
	if "polymer" in n or "rubber" in n or "stock" in n or "grip" in n or "handguard" in n:
		return polymer(Color(0.13, 0.135, 0.14) if "stock" in n or "grip" in n else Color(0.16, 0.165, 0.17))
	if "tread" in n or "floor" in n or "step" in n or "grate" in n or "walk" in n or "ladder" in n or "plinthlip" in n or "padinset" in n:
		return tread()
	if "corrug" in n or "roof" in n or "panel" in n or "slat" in n:
		return corrugated(Color(0.92, 0.78, 0.62) if "roof" in n else Color(1, 1, 1))
	if "coil" in n or "oxid" in n or "brushed" in n:
		return oxidized(Color(0.78, 0.7, 0.58), 0.68, 0.92)
	if "paint" in n:
		return painted(Color(0.78, 0.62, 0.42))
	if "dark" in n:
		return oxidized(Color(0.28, 0.26, 0.24), 0.64, 1.05)
	if "metal" in n:
		return oxidized()
	return painted(Color(0.72, 0.66, 0.56), 0.38, 1.08)


static func _pbr(key: String, dir: String, tint: Color, metallic: float, roughness_mul: float, is_metal: bool, uv_scale: float = 0.35, world_triplanar: bool = true) -> StandardMaterial3D:
	var cache_key := "%s_%s_%.2f_%.2f_%.2f_%s" % [key, tint.to_html(false), metallic, roughness_mul, uv_scale, str(world_triplanar)]
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
