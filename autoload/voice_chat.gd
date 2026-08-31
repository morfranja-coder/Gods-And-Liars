extends Node

signal local_talking_changed(is_talking: bool)
signal remote_talking(peer_id: int)

const VOICE_SAMPLE_RATE := 48000
const VOICE_RESULT_OK := 0
const VOICE_ACTION := &"voice_talk"

var is_talking: bool = false
var _steam: Object = null
var _voice_player: AudioStreamPlayer = null
var _playback: AudioStreamGeneratorPlayback = null

func _ready() -> void:
	Steamworks.steam_ready.connect(_bind_steam)
	if Steamworks.initialized:
		_bind_steam()
	_setup_playback()

func _bind_steam() -> void:
	_steam = Steamworks.get_api()

func _setup_playback() -> void:
	_voice_player = AudioStreamPlayer.new()
	_voice_player.name = "VoicePlayback"
	_voice_player.bus = "Voice"
	add_child(_voice_player)
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = VOICE_SAMPLE_RATE
	generator.buffer_length = 0.15
	_voice_player.stream = generator
	_voice_player.play()
	_playback = _voice_player.get_stream_playback()

func reset_for_match_leave() -> void:
	_set_talking(false)
	AudioSettings.clear_session_mutes()
	if _playback != null:
		_playback.clear_buffer()

func _process(_delta: float) -> void:
	if _steam == null or not Steamworks.initialized:
		return
	if NetworkManager.lobby_id == 0 or multiplayer.multiplayer_peer == null:
		_set_talking(false)
		return
	var can_talk := VoiceRouter.can_transmit(GameManager.phase, _local_alive())
	_set_talking(can_talk and Input.is_action_pressed(VOICE_ACTION))
	if is_talking:
		_capture_and_send_voice()

func _set_talking(value: bool) -> void:
	if value == is_talking:
		return
	is_talking = value
	_steam.call("setInGameVoiceSpeaking", Steamworks.steam_id, value)
	_steam.call("startVoiceRecording" if value else "stopVoiceRecording")
	local_talking_changed.emit(value)

func _capture_and_send_voice() -> void:
	var available: Dictionary = _steam.call("getAvailableVoice")
	var available_size := int(available.get("buffer", available.get("size", 0)))
	if int(available.get("result", -1)) != VOICE_RESULT_OK or available_size <= 0:
		return
	var voice: Dictionary = _steam.call("getVoice")
	var written := int(voice.get("written", voice.get("size", 0)))
	if int(voice.get("result", -1)) != VOICE_RESULT_OK or written <= 0:
		return
	var buffer: PackedByteArray = voice.get("buffer", PackedByteArray())
	if VoicePolicy.accepts_compressed_size(buffer.size()):
		_receive_voice.rpc(buffer)

@rpc("any_peer", "call_remote", "unreliable")
func _receive_voice(compressed: PackedByteArray) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	if not _can_receive_voice(sender_id, compressed):
		return
	var decompressed: Dictionary = _steam.call("decompressVoice", compressed, VOICE_SAMPLE_RATE)
	if not _valid_decompressed_voice(decompressed):
		return
	_push_decompressed_voice(sender_id, decompressed)

func _can_receive_voice(sender_id: int, compressed: PackedByteArray) -> bool:
	if _steam == null or _playback == null:
		return false
	if AudioSettings.is_peer_muted(sender_id):
		return false
	if not VoicePolicy.accepts_sender(sender_id, NetworkManager.peers):
		return false
	if not VoicePolicy.accepts_compressed_size(compressed.size()):
		return false
	var sender_alive := MatchAuthority.is_peer_publicly_alive(sender_id)
	return VoiceRouter.can_receive(GameManager.phase, sender_alive, _local_alive())

func _valid_decompressed_voice(decompressed: Dictionary) -> bool:
	if int(decompressed.get("result", -1)) != VOICE_RESULT_OK:
		return false
	var raw: PackedByteArray = decompressed.get("uncompressed", PackedByteArray())
	var byte_count := int(decompressed.get("size", raw.size()))
	if not VoicePolicy.accepts_decompressed_size(byte_count):
		return false
	return not raw.is_empty()

func _push_decompressed_voice(sender_id: int, decompressed: Dictionary) -> void:
	var raw: PackedByteArray = decompressed.get("uncompressed", PackedByteArray())
	var byte_count := int(decompressed.get("size", raw.size()))
	var usable_bytes := mini(byte_count, raw.size())
	var frame_count := usable_bytes >> 1
	var frames := PackedVector2Array()
	frames.resize(frame_count)
	for i in range(frame_count):
		var sample := raw.decode_s16(i * 2)
		var amplitude := float(sample) / 32768.0
		frames[i] = Vector2(amplitude, amplitude)
	var room := _playback.get_frames_available()
	if room > 0:
		_playback.push_buffer(frames if room >= frames.size() else frames.slice(0, room))
		remote_talking.emit(sender_id)

func _local_alive() -> bool:
	if multiplayer.multiplayer_peer == null:
		return true
	return MatchAuthority.is_peer_publicly_alive(multiplayer.get_unique_id())
