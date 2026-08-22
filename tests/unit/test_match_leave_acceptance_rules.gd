class_name MatchLeaveAcceptanceRulesTest
extends GdUnitTestSuite

func test_started_non_host_uses_client_handshake() -> void:
	assert_int(
		MatchLeaveAcceptanceRules.exit_mode(9001, false, true, false, true)
	).is_equal(MatchLeaveAcceptanceRules.ExitMode.CLIENT_HANDSHAKE)

func test_started_host_uses_host_migration() -> void:
	assert_int(
		MatchLeaveAcceptanceRules.exit_mode(9001, true, true, false, true)
	).is_equal(MatchLeaveAcceptanceRules.ExitMode.HOST_MIGRATION)

func test_pending_or_invalid_started_match_rejects_duplicate_exit() -> void:
	assert_int(
		MatchLeaveAcceptanceRules.exit_mode(9001, false, true, true, true)
	).is_equal(MatchLeaveAcceptanceRules.ExitMode.REJECT)
	assert_int(
		MatchLeaveAcceptanceRules.exit_mode(0, true, true, false, true)
	).is_equal(MatchLeaveAcceptanceRules.ExitMode.REJECT)
	assert_int(
		MatchLeaveAcceptanceRules.exit_mode(9001, false, false, false, true)
	).is_equal(MatchLeaveAcceptanceRules.ExitMode.REJECT)

func test_pre_match_lobby_does_not_enter_runtime_leave_pipeline() -> void:
	assert_int(
		MatchLeaveAcceptanceRules.exit_mode(9001, false, true, false, false)
	).is_equal(MatchLeaveAcceptanceRules.ExitMode.REJECT)
	assert_int(
		MatchLeaveAcceptanceRules.exit_mode(9001, true, true, false, false)
	).is_equal(MatchLeaveAcceptanceRules.ExitMode.REJECT)

func test_failed_pre_handoff_host_leave_is_non_terminal() -> void:
	assert_bool(
		MatchLeaveAcceptanceRules.host_transfer_failure_is_non_terminal(false, true)
	).is_true()
	assert_bool(
		MatchLeaveAcceptanceRules.host_transfer_failure_is_non_terminal(true, true)
	).is_false()
	assert_bool(
		MatchLeaveAcceptanceRules.host_transfer_failure_is_non_terminal(false, false)
	).is_false()

func test_successful_exit_requires_party_preserved_and_local_state_clean() -> void:
	var party_before := _party_snapshot()
	var party_after := _party_snapshot()
	assert_bool(
		MatchLeaveAcceptanceRules.successful_exit_contract(
			party_before,
			party_after,
			_clean_state(),
		)
	).is_true()

func test_successful_exit_contract_fails_if_party_mutates() -> void:
	var party_before := _party_snapshot()
	var party_after := _party_snapshot()
	party_after["members"] = {7001: "Leader"}
	assert_bool(
		MatchLeaveAcceptanceRules.successful_exit_contract(
			party_before,
			party_after,
			_clean_state(),
		)
	).is_false()

func test_successful_exit_contract_fails_if_match_residue_remains() -> void:
	var dirty := _clean_state()
	dirty["local_role"] = int(PlayerState.Role.HERETIC)
	assert_bool(
		MatchLeaveAcceptanceRules.successful_exit_contract(
			_party_snapshot(),
			_party_snapshot(),
			dirty,
		)
	).is_false()

func _party_snapshot() -> Dictionary:
	return MatchLeavePartyInvariant.capture(
		8100,
		9100,
		7100,
		7001,
		{7001: "Leader", 7002: "Friend"},
	)

func _clean_state() -> Dictionary:
	return {
		"lobby_id": 0,
		"peer_count": 0,
		"local_role": int(PlayerState.Role.UNASSIGNED),
		"public_alive_count": 0,
		"backup_steam_id": 0,
		"reconnect_count": 0,
		"matchmaking_state": MatchmakingManager.STATE_IDLE,
		"round_number": 0,
		"phase": int(GameManager.MatchPhase.LOBBY),
	}
