class_name QuickMatchRulesTest
extends GdUnitTestSuite

func test_target_match_requires_exactly_eight_players() -> void:
	assert_bool(QuickMatchRules.can_form_match([5, 3])).is_true()
	assert_bool(QuickMatchRules.can_form_match([4, 2, 1, 1])).is_true()
	assert_bool(QuickMatchRules.can_form_match([3, 3, 2])).is_true()
	assert_bool(QuickMatchRules.can_form_match([5, 2])).is_false()
	assert_bool(QuickMatchRules.can_form_match([5, 4])).is_false()

func test_party_is_never_split_and_size_is_bounded() -> void:
	assert_bool(QuickMatchRules.valid_party_size(1)).is_true()
	assert_bool(QuickMatchRules.valid_party_size(8)).is_true()
	assert_bool(QuickMatchRules.valid_party_size(0)).is_false()
	assert_bool(QuickMatchRules.valid_party_size(9)).is_false()

func test_progressive_search_expands_over_time() -> void:
	assert_int(QuickMatchRules.distance_tier_for_elapsed(0)).is_equal(QuickMatchRules.DISTANCE_CLOSE)
	assert_int(QuickMatchRules.distance_tier_for_elapsed(10000)).is_equal(QuickMatchRules.DISTANCE_DEFAULT)
	assert_int(QuickMatchRules.distance_tier_for_elapsed(20000)).is_equal(QuickMatchRules.DISTANCE_FAR)
	assert_int(QuickMatchRules.distance_tier_for_elapsed(40000)).is_equal(QuickMatchRules.DISTANCE_WORLDWIDE)

func test_exact_fit_finds_five_plus_three() -> void:
	var candidates: Array[Dictionary] = [
		{"id": 101, "party_size": 2, "wait_ms": 8000},
		{"id": 102, "party_size": 3, "wait_ms": 5000},
	]
	assert_array(QuickMatchRules.find_exact_fit(5, candidates)).contains_exactly([102])

func test_exact_fit_can_combine_multiple_parties() -> void:
	var candidates: Array[Dictionary] = [
		{"id": 201, "party_size": 2, "wait_ms": 12000},
		{"id": 202, "party_size": 1, "wait_ms": 9000},
		{"id": 203, "party_size": 1, "wait_ms": 6000},
	]
	assert_array(QuickMatchRules.find_exact_fit(4, candidates)).contains_exactly([201, 202, 203])
