class_name QAAdversarialSimulatorTest
extends GdUnitTestSuite

func test_afk_night_actor_is_detected_as_blocking_without_timeout_policy() -> void:
	var result := QAAdversarialSimulator.run(
		101,
		QAAdversarialSimulator.Fault.AFK_NIGHT,
		0,
	)
	assert_bool(bool(result.get("blocked", false))).is_true()
	assert_bool(bool(result.get("fault_consumed", false))).is_true()
	assert_bool(bool(result.get("completed", true))).is_false()

func test_invalid_vote_is_rejected_and_exposes_missing_vote_timeout() -> void:
	var result := QAAdversarialSimulator.run(
		202,
		QAAdversarialSimulator.Fault.INVALID_VOTE,
		0,
	)
	assert_bool(bool(result.get("blocked", false))).is_true()
	assert_bool(bool(result.get("fault_consumed", false))).is_true()
	assert_bool(bool(result.get("completed", true))).is_false()

func test_duplicate_vote_does_not_create_an_extra_vote_or_deadlock() -> void:
	var result := QAAdversarialSimulator.run(
		303,
		QAAdversarialSimulator.Fault.DUPLICATE_VOTE,
		0,
	)
	assert_bool(bool(result.get("fault_consumed", false))).is_true()
	assert_bool(bool(result.get("blocked", true))).is_false()
	assert_bool(bool(result.get("completed", false))).is_true()
	assert_str(str(result.get("winner", ""))).is_not_empty()

func test_disconnect_after_night_does_not_deadlock_match() -> void:
	var result := QAAdversarialSimulator.run(
		404,
		QAAdversarialSimulator.Fault.DISCONNECT_AFTER_NIGHT,
		0,
	)
	assert_bool(bool(result.get("fault_consumed", false))).is_true()
	assert_bool(bool(result.get("blocked", true))).is_false()
	assert_bool(bool(result.get("completed", false))).is_true()
	assert_str(str(result.get("winner", ""))).is_not_empty()

func test_balanced_adversarial_harness_completes_250_seeds() -> void:
	for seed_value in range(1, 251):
		var result := QAAdversarialSimulator.run(seed_value)
		assert_bool(bool(result.get("completed", false))).is_true()
		assert_bool(bool(result.get("blocked", true))).is_false()
		assert_int(int(result.get("players", 0))).is_equal(QuickMatchRules.TARGET_PLAYERS)
		assert_int(int(result.get("rounds", 999))).is_less_equal(QAAdversarialSimulator.DEFAULT_MAX_ROUNDS)

func test_duplicate_vote_stress_completes_100_seeds() -> void:
	for seed_value in range(500, 600):
		var result := QAAdversarialSimulator.run(
			seed_value,
			QAAdversarialSimulator.Fault.DUPLICATE_VOTE,
			0,
		)
		assert_bool(bool(result.get("completed", false))).is_true()
		assert_bool(bool(result.get("blocked", true))).is_false()

func test_disconnect_stress_completes_100_seeds() -> void:
	for seed_value in range(700, 800):
		var result := QAAdversarialSimulator.run(
			seed_value,
			QAAdversarialSimulator.Fault.DISCONNECT_AFTER_NIGHT,
			0,
		)
		assert_bool(bool(result.get("completed", false))).is_true()
		assert_bool(bool(result.get("blocked", true))).is_false()
