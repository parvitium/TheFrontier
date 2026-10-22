extends Node

signal changed

enum Quality { LOW, MEDIUM, HIGH, ULTRA }

const PATH := "user://settings.cfg"

var mouse_sensitivity: float = 1.0
var fov: float = 78.0
var master_volume: float = 0.8
var sfx_volume: float = 1.0
var quality: int = Quality.HIGH


func _ready() -> void:
	load_from_disk()
	apply_audio()
	apply_viewport()
	Landscape.warmup()
	KitFactory.warmup()
	if ResourceLoader.exists(WorldLook.HDRI_PATH):
		load(WorldLook.HDRI_PATH)


func set_mouse_sensitivity(v: float) -> void:
	mouse_sensitivity = clampf(v, 0.3, 2.5)
	_emit_save()


func set_fov(v: float) -> void:
	fov = clampf(v, 60.0, 100.0)
	_emit_save()


func set_master_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	apply_audio()
	_emit_save()


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	apply_audio()
	_emit_save()


func set_quality(v: int) -> void:
	quality = clampi(v, Quality.LOW, Quality.ULTRA)
	apply_viewport()
	_emit_save()


func quality_name() -> String:
	match quality:
		Quality.LOW:
			return "Low"
		Quality.MEDIUM:
			return "Medium"
		Quality.HIGH:
			return "High"
		_:
			return "Ultra"


func apply_audio() -> void:
	var db := linear_to_db(maxf(0.0001, master_volume))
	AudioServer.set_bus_volume_db(0, db)


func apply_viewport() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	match quality:
		Quality.LOW:
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.scaling_3d_scale = 0.85
		Quality.MEDIUM:
			vp.msaa_3d = Viewport.MSAA_2X
			vp.scaling_3d_scale = 1.0
		Quality.HIGH:
			vp.msaa_3d = Viewport.MSAA_2X
			vp.scaling_3d_scale = 1.0
		Quality.ULTRA:
			vp.msaa_3d = Viewport.MSAA_4X
			vp.scaling_3d_scale = 1.0


func apply_environment(env: Environment, sun: DirectionalLight3D = null) -> void:
	if env == null:
		return
	var fp := RenderingServer.get_current_rendering_method() == "forward_plus"
	env.glow_enabled = quality >= Quality.MEDIUM
	env.glow_intensity = 0.45 if quality >= Quality.HIGH else 0.28
	env.glow_bloom = 0.12 if quality >= Quality.HIGH else 0.04
	env.glow_hdr_threshold = 0.85
	env.ssao_enabled = fp and quality >= Quality.HIGH
	env.ssao_radius = 1.35
	env.ssao_intensity = 1.8 if quality == Quality.ULTRA else 1.25
	env.volumetric_fog_enabled = fp and quality >= Quality.HIGH
	env.fog_enabled = quality >= Quality.MEDIUM
	if sun:
		sun.shadow_enabled = quality >= Quality.LOW
		sun.directional_shadow_max_distance = 240.0 if quality >= Quality.HIGH else 90.0
		sun.light_angular_distance = 0.5 if quality >= Quality.HIGH else 1.2


func load_from_disk() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	mouse_sensitivity = float(cfg.get_value("input", "mouse_sensitivity", mouse_sensitivity))
	fov = float(cfg.get_value("input", "fov", fov))
	master_volume = float(cfg.get_value("audio", "master_volume", master_volume))
	sfx_volume = float(cfg.get_value("audio", "sfx_volume", sfx_volume))
	quality = int(cfg.get_value("graphics", "quality", quality))
	mouse_sensitivity = clampf(mouse_sensitivity, 0.3, 2.5)
	fov = clampf(fov, 60.0, 100.0)
	master_volume = clampf(master_volume, 0.0, 1.0)
	sfx_volume = clampf(sfx_volume, 0.0, 1.0)
	quality = clampi(quality, Quality.LOW, Quality.ULTRA)


func save_to_disk() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("input", "fov", fov)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("graphics", "quality", quality)
	cfg.save(PATH)


func _emit_save() -> void:
	save_to_disk()
	changed.emit()
