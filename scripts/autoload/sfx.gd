extends Node

var _streams: Dictionary = {}
var _player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.name = "Player"
	_player.bus = "Master"
	add_child(_player)
	_load("ui_hover", "res://assets/sfx/ui_hover.wav")
	_load("ui_click", "res://assets/sfx/ui_click.wav")
	_load("ui_back", "res://assets/sfx/ui_back.wav")
	_load("fire_rifle", "res://assets/sfx/fire_rifle.wav")
	_load("fire_shotgun", "res://assets/sfx/fire_shotgun.wav")
	_load("place_build", "res://assets/sfx/place_build.wav")
	_load("turret_shot", "res://assets/sfx/turret_shot.wav")


func play(id: String, pitch: float = 1.0) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not _streams.has(id) or _player == null:
		return
	_player.stream = _streams[id]
	_player.pitch_scale = clampf(pitch, 0.6, 1.6)
	_player.volume_db = linear_to_db(maxf(0.0001, GameSettings.sfx_volume))
	_player.play()


func _load(id: String, path: String) -> void:
	if ResourceLoader.exists(path):
		_streams[id] = load(path)
