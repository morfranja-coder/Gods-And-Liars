class_name IdentityPolicyTest
extends GdUnitTestSuite

func test_valid_identity_requires_positive_steam_id() -> void:
	assert_bool(IdentityPolicy.valid_identity(0, "Player")).is_false()
	assert_bool(IdentityPolicy.valid_identity(76561198000000000, "Player")).is_true()

func test_display_name_is_trimmed_and_bounded() -> void:
	assert_str(IdentityPolicy.sanitize_display_name("  Player  ")).is_equal("Player")
	var long_name := "X".repeat(IdentityPolicy.MAX_DISPLAY_NAME_LENGTH + 10)
	assert_int(IdentityPolicy.sanitize_display_name(long_name).length()).is_equal(IdentityPolicy.MAX_DISPLAY_NAME_LENGTH)

func test_blank_display_name_is_rejected() -> void:
	assert_bool(IdentityPolicy.valid_display_name("   ")).is_false()

func test_duplicate_steam_id_is_detected() -> void:
	var peers := {
		1: LobbyRules.make_peer(111, "Host"),
		2: LobbyRules.make_peer(222, "Guest"),
	}
	assert_bool(IdentityPolicy.steam_id_in_use(peers, 111)).is_true()
	assert_bool(IdentityPolicy.steam_id_in_use(peers, 333)).is_false()

func test_current_peer_can_refresh_same_steam_id() -> void:
	var peers := {2: LobbyRules.make_peer(222, "Guest")}
	assert_bool(IdentityPolicy.steam_id_in_use(peers, 222, 2)).is_false()
