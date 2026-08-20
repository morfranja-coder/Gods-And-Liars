extends Node

signal local_talking_changed(is_talking: bool)
signal remote_talking(peer_id: int)

const VOICE_SAMPLE_RATE := 48000
const VOICE_RESULT_OK := 0

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
	add_child(_voice_player)
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = VOICE_SAMPLE_RATE
	generator.buffer_length = 0.15
	_voice_player.stream = generator
	_voice_player.play()
	_playback = _voice_player.get_stream_playback()

func _process(_delta: float) -> void:
	if _steam == null or not Steamworks.initialized:
		return
	if NetworkManager.lobby_id == 0 or multiplayer.multiplayer_peer == null:
		_set_talking(false)
		return
	_set_talking(Input.is_action_pressed("voice_talk"))
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
	if not buffer.is_empty():
		_receive_voice.rpc(buffer)

@rpc("any_peer", "call_remote", "unreliable")
func _receive_voice(compressed: PackedByteArray) -> void:
	if _steam == null or _playback == null:
		return
	var decompressed: Dictionary = _steam.call("decompressVoice", compressed, VOICE_SAMPLE_RATE)
	var byte_count := int(decompressed.get("size", 0))
	if int(decompressed.get("result", -1)) != VOICE_RESULT_OK or byte_count <= 0:
		return
	var raw: PackedByteArray = decompressed.get("uncompressed", PackedByteArray())
	if raw.is_empty():
		return
	var frame_count := mini(byte_count / 2, raw.size() / 2)
	var frames := PackedVector2Array()
	frames.resize(frame_count)
	for i in range(frame_count):
		var sample := raw.decode_s16(i * 2)
		var amplitude := float(sample) / 32768.0
		frames[i] = Vector2(amplitude, amplitude)
	var room := _playback.get_frames_available()
	if room <= 0:
		return
	_playback.push_buffer(frames if room >= frames.size() else frames.slice(0, room))
	remote_talking.emit(multiplayer.get_remote_sender_id())
