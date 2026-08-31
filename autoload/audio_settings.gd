extends Node

signal settings_changed
signal push_to_talk_changed(keycode: int)
signal peer_mute_changed(peer_id: int, muted: bool)

const CONFIG_PATH := "user://gods_liars_audio.cfg"
const SECTION_AUDIO := "audio"
const SECTION_INPUT := "input"
const VOICE_ACTION := &"voice_talk"
const DEFAULT_PTT_KEY := KEY_V

var master_volume: float = 1.0
var music_volume: float = 0.8
var sfx_volume: float = 1.0
var voice_volume: float = 1.0
var push_to_talk_key: int = DEFAULT_PTT_KEY
var _muted_peers: Dictionary = {}

func _ready() -> void:
	_ensure_bus("Music")
	_ensure_bus("SFX")
	_ensure_bus("Voice")
	load_settings()
	apply_settings()

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	master_volume = clampf(float(config.get_value(SECTION_AUDIO, "master", 1.0)), 0.0, 1.0)
	music_volume = clampf(float(config.get_value(SECTION_AUDIO, "music", 0.8)), 0.0, 1.0)
	sfx_volume = clampf(float(config.get_value(SECTION_AUDIO, "sfx", 1.0)), 0.0, 1.0)
	voice_volume = clampf(float(config.get_value(SECTION_AUDIO, "voice", 1.0)), 0.0, 1.0)
	push_to_talk_key = int(config.get_value(SECTION_INPUT, "push_to_talk_key", DEFAULT_PTT_KEY))

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION_AUDIO, "master", master_volume)
	config.set_value(SECTION_AUDIO, "music", music_volume)
	config.set_value(SECTION_AUDIO, "sfx", sfx_volume)
	config.set_value(SECTION_AUDIO, "voice", voice_volume)
	config.set_value(SECTION_INPUT, "push_to_talk_key", push_to_talk_key)
	config.save(CONFIG_PATH)

func apply_settings() -> void:
	_set_bus_volume("Master", master_volume)
	_set_bus_volume("Music", music_volume)
	_set_bus_volume("SFX", sfx_volume)
	_set_bus_volume("Voice", voice_volume)
	_apply_push_to_talk_key()
	settings_changed.emit()

func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_set_bus_volume("Master", master_volume)
	_save_and_notify()

func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_set_bus_volume("Music", music_volume)
	_save_and_notify()

func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_set_bus_volume("SFX", sfx_volume)
	_save_and_notify()

func set_voice_volume(value: float) -> void:
	voice_volume = clampf(value, 0.0, 1.0)
	_set_bus_volume("Voice", voice_volume)
	_save_and_notify()

func set_push_to_talk_key(keycode: int) -> void:
	if keycode <= 0:
		return
	push_to_talk_key = keycode
	_apply_push_to_talk_key()
	save_settings()
	push_to_talk_changed.emit(keycode)
	settings_changed.emit()

func push_to_talk_label() -> String:
	return OS.get_keycode_string(push_to_talk_key)

func set_peer_muted(peer_id: int, muted: bool) -> void:
	if peer_id <= 0:
		return
	if muted:
		_muted_peers[peer_id] = true
	else:
		_muted_peers.erase(peer_id)
	peer_mute_changed.emit(peer_id, muted)

func toggle_peer_muted(peer_id: int) -> bool:
	var muted := not is_peer_muted(peer_id)
	set_peer_muted(peer_id, muted)
	return muted

func is_peer_muted(peer_id: int) -> bool:
	return bool(_muted_peers.get(peer_id, false))

func clear_session_mutes() -> void:
	_muted_peers.clear()

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)

func _set_bus_volume(bus_name: String, value: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.0001)))
	AudioServer.set_bus_mute(index, value <= 0.0001)

func _apply_push_to_talk_key() -> void:
	if not InputMap.has_action(VOICE_ACTION):
		InputMap.add_action(VOICE_ACTION)
	InputMap.action_erase_events(VOICE_ACTION)
	var event := InputEventKey.new()
	event.physical_keycode = push_to_talk_key
	InputMap.action_add_event(VOICE_ACTION, event)

func _save_and_notify() -> void:
	save_settings()
	settings_changed.emit()
