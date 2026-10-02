class_name MatchProtocolRulesTest
extends GdUnitTestSuite

func test_rejects_missing_or_mismatched_versions() -> void:
	assert_bool(MatchProtocolRules.compatible_protocol("")).is_false()
	assert_bool(MatchProtocolRules.compatible_protocol("0")).is_false()
	assert_bool(MatchProtocolRules.compatible_protocol("999")).is_false()

func test_accepts_current_version() -> void:
	assert_bool(
		MatchProtocolRules.compatible_protocol(MatchProtocolRules.protocol_value())
	).is_true()

func test_build_version_always_has_publishable_value() -> void:
	assert_str(MatchProtocolRules.current_build_version()).is_not_empty()

func test_network_and_matchmaking_share_protocol_metadata_key() -> void:
	assert_str(NetworkManager.PROTOCOL_VERSION_KEY).is_equal(
		MatchmakingManager.PROTOCOL_VERSION_KEY
	)
	assert_str(NetworkManager.PROTOCOL_VERSION_KEY).is_equal(
		MatchProtocolRules.PROTOCOL_VERSION_KEY
	)
