class_name MatchLeaveRulesTest
extends GdUnitTestSuite

func test_non_host_can_request_leave_with_active_match_peer() -> void:
	assert_bool(
		MatchLeaveRules.can_request_non_host_leave(9001, false, true, false)
	).is_true()

func test_host_cannot_use_non_host_leave_path() -> void:
	assert_bool(
		MatchLeaveRules.can_request_non_host_leave(9001, true, true, false)
	).is_false()

func test_leave_requires_lobby_peer_and_no_pending_request() -> void:
	assert_bool(
		MatchLeaveRules.can_request_non_host_leave(0, false, true, false)
	).is_false()
	assert_bool(
		MatchLeaveRules.can_request_non_host_leave(9001, false, false, false)
	).is_false()
	assert_bool(
		MatchLeaveRules.can_request_non_host_leave(9001, false, true, true)
	).is_false()

func test_host_can_request_leave_only_with_active_transport() -> void:
	assert_bool(
		MatchLeaveRules.can_request_host_leave(9001, true, true, false)
	).is_true()
	assert_bool(
		MatchLeaveRules.can_request_host_leave(0, true, true, false)
	).is_false()
	assert_bool(
		MatchLeaveRules.can_request_host_leave(9001, false, true, false)
	).is_false()
	assert_bool(
		MatchLeaveRules.can_request_host_leave(9001, true, false, false)
	).is_false()
	assert_bool(
		MatchLeaveRules.can_request_host_leave(9001, true, true, true)
	).is_false()

func test_host_transfer_error_keeps_concrete_reason() -> void:
	var message := MatchLeaveRules.normalize_host_transfer_error("Steam rejected transfer.")
	assert_bool(message.contains("Steam rejected transfer.")).is_true()
	assert_bool(message.contains("partida sigue activa")).is_true()

func test_empty_host_transfer_error_uses_safe_default() -> void:
	assert_str(MatchLeaveRules.normalize_host_transfer_error("   ")).is_equal(
		MatchLeaveRules.DEFAULT_HOST_TRANSFER_ERROR
	)

func test_server_accepts_matching_remote_identity() -> void:
	var roster := {
		1: {"steam_id": 7001},
		5: {"steam_id": 7005},
	}
	assert_bool(MatchLeaveRules.server_accepts_leave(5, 7005, roster)).is_true()

func test_server_rejects_host_unknown_or_spoofed_identity() -> void:
	var roster := {
		1: {"steam_id": 7001},
		5: {"steam_id": 7005},
	}
	assert_bool(MatchLeaveRules.server_accepts_leave(1, 7001, roster)).is_false()
	assert_bool(MatchLeaveRules.server_accepts_leave(9, 7009, roster)).is_false()
	assert_bool(MatchLeaveRules.server_accepts_leave(5, 9999, roster)).is_false()
