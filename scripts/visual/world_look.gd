class_name WorldLook
extends RefCounted

const HDRI_PATH := "res://assets/env/the_sky_is_on_fire.hdr"


static func attach(root: Node3D, cinematic: bool = false) -> Dictionary:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-16, 128, 0)
	sun.light_color = Color(1.0, 0.52, 0.28)
	sun.light_energy = 1.65 if cinematic else 1.45
	sun.shadow_enabled = true
	sun.shadow_blur = 1.15
	sun.light_angular_distance = 0.55
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 96.0
	root.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.rotation_degrees = Vector3(-48, -36, 0)
	fill.light_color = Color(0.32, 0.42, 0.62)
	fill.light_energy = 0.28
	fill.shadow_enabled = false
	root.add_child(fill)
	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	env_node.environment = make_environment(cinematic)
	root.add_child(env_node)
	GameSettings.apply_environment(env_node.environment, sun)
	GameSettings.apply_viewport()
	var binder := Node.new()
	binder.name = "LookBinder"
	root.add_child(binder)
	GameSettings.changed.connect(func() -> void:
		if is_instance_valid(env_node) and is_instance_valid(sun):
			GameSettings.apply_environment(env_node.environment, sun)
			GameSettings.apply_viewport()
	)
	return {sun = sun, environment = env_node.environment, node = env_node}


static func make_environment(cinematic: bool = false) -> Environment:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = _make_sky()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.42
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.tonemap_exposure = 0.92 if cinematic else 1.0
	environment.tonemap_white = 6.0
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.04
	environment.adjustment_contrast = 1.08
	environment.adjustment_saturation = 1.12
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.72, 0.42, 0.22)
	environment.fog_sun_scatter = 0.35
	environment.fog_density = 0.007 if cinematic else 0.0055
	environment.fog_aerial_perspective = 0.55
	environment.fog_sky_affect = 0.45
	environment.volumetric_fog_density = 0.022 if cinematic else 0.016
	environment.volumetric_fog_albedo = Color(0.78, 0.48, 0.28)
	environment.volumetric_fog_emission = Color(0.18, 0.07, 0.03)
	environment.volumetric_fog_emission_energy = 0.35
	environment.volumetric_fog_anisotropy = 0.3
	environment.volumetric_fog_length = 72.0
	environment.volumetric_fog_ambient_inject = 0.45
	environment.volumetric_fog_sky_affect = 0.7
	environment.glow_enabled = true
	environment.glow_normalized = true
	environment.glow_intensity = 0.55
	environment.glow_bloom = 0.14
	environment.glow_hdr_threshold = 0.8
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	environment.ssao_enabled = true
	environment.ssao_radius = 1.4
	environment.ssao_intensity = 1.5
	environment.ssao_power = 1.5
	environment.ssao_horizon = 0.06
	return environment


static func _make_sky() -> Sky:
	var sky := Sky.new()
	if ResourceLoader.exists(HDRI_PATH):
		var pan := PanoramaSkyMaterial.new()
		pan.panorama = load(HDRI_PATH)
		pan.energy_multiplier = 0.82
		sky.sky_material = pan
	else:
		var proc := ProceduralSkyMaterial.new()
		proc.sky_top_color = Color(0.18, 0.16, 0.28)
		proc.sky_horizon_color = Color(0.92, 0.42, 0.18)
		proc.ground_bottom_color = Color(0.08, 0.06, 0.05)
		proc.ground_horizon_color = Color(0.45, 0.22, 0.12)
		proc.sun_angle_max = 22.0
		sky.sky_material = proc
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	return sky


