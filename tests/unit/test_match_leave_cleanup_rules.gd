class_name MatchLeaveCleanupRulesTest
extends GdUnitTestSuite

func test_clean_match_leave_state_is_accepted() -> void:
	assert_bool(
		MatchLeaveCleanupRules.is_clean(
			0,
			0,
			int(PlayerState.Role.UNASSIGNED),
			0,
			0,
			0,
			MatchmakingManager.STATE_IDLE,
			0,
			int(GameManager.MatchPhase.LOBBY),
		)
	).is_true()

func test_cleanup_rejects_network_or_role_residue() -> void:
	assert_bool(
		MatchLeaveCleanupRules.is_clean(
			44,
			0,
			int(PlayerState.Role.UNASSIGNED),
			0,
			0,
			0,
			MatchmakingManager.STATE_IDLE,
			0,
			int(GameManager.MatchPhase.LOBBY),
		)
	).is_false()
	assert_bool(
		MatchLeaveCleanupRules.is_clean(
			0,
			0,
			int(PlayerState.Role.HERETIC),
			0,
			0,
			0,
			MatchmakingManager.STATE_IDLE,
			0,
			int(GameManager.MatchPhase.LOBBY),
		)
	).is_false()

func test_cleanup_rejects_migration_or_matchmaking_residue() -> void:
	assert_bool(
		MatchLeaveCleanupRules.is_clean(
			0,
			0,
			int(PlayerState.Role.UNASSIGNED),
			0,
			7002,
			0,
			MatchmakingManager.STATE_IDLE,
			0,
			int(GameManager.MatchPhase.LOBBY),
		)
	).is_false()
	assert_bool(
		MatchLeaveCleanupRules.is_clean(
			0,
			0,
			int(PlayerState.Role.UNASSIGNED),
			0,
			0,
			2,
			MatchmakingManager.STATE_MATCH_FOUND,
			0,
			int(GameManager.MatchPhase.LOBBY),
		)
	).is_false()

func test_cleanup_requires_lobby_phase_and_zero_round() -> void:
	assert_bool(
		MatchLeaveCleanupRules.is_clean(
			0,
			0,
			int(PlayerState.Role.UNASSIGNED),
			0,
			0,
			0,
			MatchmakingManager.STATE_IDLE,
			2,
			int(GameManager.MatchPhase.VOTING),
		)
	).is_false()