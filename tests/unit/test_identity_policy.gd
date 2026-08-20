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
