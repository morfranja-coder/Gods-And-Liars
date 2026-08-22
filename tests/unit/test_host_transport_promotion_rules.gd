class_name HostTransportPromotionRulesTest
extends GdUnitTestSuite

func test_valid_backup_owner_can_promote() -> void:
	assert_bool(
		HostTransportPromotionRules.can_promote(7001, 1002, 1002, 1002, true, false)
	).is_true()

func test_non_backup_cannot_promote() -> void:
	assert_bool(
		HostTransportPromotionRules.can_promote(7001, 1003, 1002, 1002, true, false)
	).is_false()

func test_unconfirmed_owner_blocks_promotion() -> void:
	assert_bool(
		HostTransportPromotionRules.can_promote(7001, 1002, 1002, 1003, true, false)
	).is_false()

func test_missing_snapshot_blocks_promotion() -> void:
	assert_bool(
		HostTransportPromotionRules.can_promote(7001, 1002, 1002, 1002, false, false)
	).is_false()

func test_existing_multiplayer_peer_blocks_duplicate_promotion() -> void:
	assert_bool(
		HostTransportPromotionRules.can_promote(7001, 1002, 1002, 1002, true, true)
	).is_false()

func test_invalid_lobby_blocks_promotion() -> void:
	assert_bool(
		HostTransportPromotionRules.can_promote(0, 1002, 1002, 1002, true, false)
	).is_false()
