class_name MatchmakingManagerTest
extends GdUnitTestSuite

func before_test() -> void:
	MatchmakingManager.reset()

func after_test() -> void:
	MatchmakingManager.reset()

func test_party_of_five_queues_for_three_slots_and_finds_exact_party() -> void:
	assert_bool(MatchmakingManager.start_quick_match(5)).is_true()
	assert_int(MatchmakingManager.slots_needed()).is_equal(3)
	var candidates: Array[Dictionary] = [
		{"id": 10, "party_size": 2, "wait_ms": 10000},
		{"id": 20, "party_size": 3, "wait_ms": 5000},
	]
	var result := MatchmakingManager.consider_candidates(candidates)
	assert_int(result.size()).is_equal(1)
	assert_int(result[0]).is_equal(20)
	assert_str(str(MatchmakingManager.state)).is_equal("match_found")

func test_invalid_party_cannot_enter_queue() -> void:
	assert_bool(MatchmakingManager.start_quick_match(9)).is_false()
	assert_str(str(MatchmakingManager.state)).is_equal("idle")

func test_cancel_returns_queue_to_idle() -> void:
	assert_bool(MatchmakingManager.start_quick_match(1)).is_true()
	MatchmakingManager.cancel_quick_match()
	assert_str(str(MatchmakingManager.state)).is_equal("idle")
