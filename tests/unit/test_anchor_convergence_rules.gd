class_name AnchorConvergenceRulesTest
extends GdUnitTestSuite

func test_five_plus_three_anchors_can_merge() -> void:
	assert_bool(AnchorConvergenceRules.can_merge(5, 3, 5)).is_true()

func test_four_plus_four_anchors_can_merge() -> void:
	assert_bool(AnchorConvergenceRules.can_merge(4, 4, 4)).is_true()

func test_combination_over_eight_is_rejected() -> void:
	assert_bool(AnchorConvergenceRules.can_merge(6, 3, 5)).is_false()

func test_anchor_that_already_mixed_parties_is_not_pure() -> void:
	assert_bool(AnchorConvergenceRules.is_pure_anchor(3, 3)).is_false()
	assert_bool(AnchorConvergenceRules.can_merge(2, 3, 3)).is_false()

func test_only_higher_lobby_id_migrates() -> void:
	assert_bool(AnchorConvergenceRules.should_migrate(200, 5, 100, 3, 5)).is_true()
	assert_bool(AnchorConvergenceRules.should_migrate(100, 3, 200, 5, 3)).is_false()

func test_same_lobby_never_migrates_to_itself() -> void:
	assert_bool(AnchorConvergenceRules.should_migrate(100, 4, 100, 4, 4)).is_false()
