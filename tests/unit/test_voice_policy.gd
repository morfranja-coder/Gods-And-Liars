class_name VoicePolicyTest
extends GdUnitTestSuite

func test_voice_accepts_only_known_peers() -> void:
	var peers := {2: LobbyRules.make_peer(1002, "Guest")}
	assert_bool(VoicePolicy.accepts_sender(2, peers)).is_true()
	assert_bool(VoicePolicy.accepts_sender(3, peers)).is_false()
	assert_bool(VoicePolicy.accepts_sender(0, peers)).is_false()

func test_voice_rejects_empty_and_oversized_compressed_packets() -> void:
	assert_bool(VoicePolicy.accepts_compressed_size(0)).is_false()
	assert_bool(VoicePolicy.accepts_compressed_size(1024)).is_true()
	assert_bool(VoicePolicy.accepts_compressed_size(VoicePolicy.MAX_COMPRESSED_BYTES + 1)).is_false()

func test_voice_rejects_oversized_decompressed_audio() -> void:
	assert_bool(VoicePolicy.accepts_decompressed_size(96000)).is_true()
	assert_bool(VoicePolicy.accepts_decompressed_size(VoicePolicy.MAX_DECOMPRESSED_BYTES + 1)).is_false()
