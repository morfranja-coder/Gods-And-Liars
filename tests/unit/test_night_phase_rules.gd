class_name NightPhaseRulesTest
extends GdUnitTestSuite

func test_night_phase_order_is_deterministic() -> void:
	assert_int(NightPhaseRules.next_action_phase(GameManager.MatchPhase.NIGHT_START)).is_equal(GameManager.MatchPhase.HERETIC_ACTION)
	assert_int(NightPhaseRules.next_action_phase(GameManager.MatchPhase.HERETIC_ACTION)).is_equal(GameManager.MatchPhase.HEALER_ACTION)
	assert_int(NightPhaseRules.next_action_phase(GameManager.MatchPhase.HEALER_ACTION)).is_equal(GameManager.MatchPhase.INQUISITOR_ACTION)
	assert_int(NightPhaseRules.next_action_phase(GameManager.MatchPhase.INQUISITOR_ACTION)).is_equal(GameManager.MatchPhase.NIGHT_RESOLUTION)

func test_action_phase_maps_to_expected_role() -> void:
	assert_int(NightPhaseRules.role_for_phase(GameManager.MatchPhase.HERETIC_ACTION)).is_equal(PlayerState.Role.HERETIC)
	assert_int(NightPhaseRules.role_for_phase(GameManager.MatchPhase.HEALER_ACTION)).is_equal(PlayerState.Role.HEALER)
	assert_int(NightPhaseRules.role_for_phase(GameManager.MatchPhase.INQUISITOR_ACTION)).is_equal(PlayerState.Role.INQUISITOR)
	assert_int(NightPhaseRules.role_for_phase(GameManager.MatchPhase.DAY_DISCUSSION)).is_equal(PlayerState.Role.UNASSIGNED)
