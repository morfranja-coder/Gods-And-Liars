class_name PhaseTimeoutPolicyTest
extends GdUnitTestSuite

func test_only_blocking_match_phases_have_timeouts() -> void:
	assert_int(PhaseTimeoutPolicy.timeout_ms_for_phase(GameManager.MatchPhase.ROLE_REVEAL)).is_equal(15000)
	assert_int(PhaseTimeoutPolicy.timeout_ms_for_phase(GameManager.MatchPhase.HERETIC_ACTION)).is_equal(20000)
	assert_int(PhaseTimeoutPolicy.timeout_ms_for_phase(GameManager.MatchPhase.HEALER_ACTION)).is_equal(20000)
	assert_int(PhaseTimeoutPolicy.timeout_ms_for_phase(GameManager.MatchPhase.INQUISITOR_ACTION)).is_equal(20000)
	assert_int(PhaseTimeoutPolicy.timeout_ms_for_phase(GameManager.MatchPhase.DAY_DISCUSSION)).is_equal(90000)
	assert_int(PhaseTimeoutPolicy.timeout_ms_for_phase(GameManager.MatchPhase.VOTING)).is_equal(30000)
	assert_int(PhaseTimeoutPolicy.timeout_ms_for_phase(GameManager.MatchPhase.MATCH_END)).is_equal(0)

func test_deadline_adds_phase_duration_to_host_clock() -> void:
	assert_int(
		PhaseTimeoutPolicy.deadline_ms(GameManager.MatchPhase.VOTING, 1000)
	).is_equal(31000)
	assert_int(
		PhaseTimeoutPolicy.deadline_ms(GameManager.MatchPhase.MATCH_END, 1000)
	).is_equal(0)
