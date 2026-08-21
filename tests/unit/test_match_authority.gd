class_name MatchAuthorityTest
extends GdUnitTestSuite

func before_test() -> void:
	MatchAuthority.reset()
	GameManager.reset_match()

func after_test() -> void:
	MatchAuthority.reset()
	GameManager.reset_match()

func test_private_role_receive_stores_only_local_role() -> void:
	MatchAuthority._receive_private_role(int(PlayerState.Role.HERETIC))
	assert_int(int(MatchAuthority.local_role)).is_equal(int(PlayerState.Role.HERETIC))
	assert_bool(MatchAuthority.get("_session") == null).is_true()

func test_invalid_private_role_is_ignored() -> void:
	MatchAuthority._receive_private_role(999)
	assert_int(int(MatchAuthority.local_role)).is_equal(int(PlayerState.Role.UNASSIGNED))

func test_private_role_labels_are_local_only() -> void:
	MatchAuthority._receive_private_role(int(PlayerState.Role.HEALER))
	assert_str(MatchAuthority.role_title()).is_equal("Sanador")
	assert_bool(MatchAuthority.role_description().contains("Protegé")).is_true()

func test_build_session_preserves_authoritative_seats() -> void:
	var roster := {
		1: {"steam_id": 1001, "display_name": "A", "seat_id": 4},
		2: {"steam_id": 1002, "display_name": "B", "seat_id": 1},
		3: {"steam_id": 1003, "display_name": "C", "seat_id": 7},
		4: {"steam_id": 1004, "display_name": "D", "seat_id": 2},
	}
	var session: MatchSession = MatchAuthority.call("_build_session", roster)
	assert_bool(session != null).is_true()
	assert_int(session.get_player(1).seat_id).is_equal(4)
	assert_int(session.get_player(2).seat_id).is_equal(1)
	assert_int(session.get_player(3).seat_id).is_equal(7)
	assert_int(session.get_player(4).seat_id).is_equal(2)

func test_phase_sync_updates_round_number() -> void:
	MatchAuthority._sync_phase(int(GameManager.MatchPhase.DAY_DISCUSSION), 3)
	assert_int(int(GameManager.phase)).is_equal(int(GameManager.MatchPhase.DAY_DISCUSSION))
	assert_int(GameManager.round_number).is_equal(3)

func test_disconnect_marks_session_player_dead_and_clears_pending_actions() -> void:
	var roster := {
		1: {"steam_id": 1001, "display_name": "A", "seat_id": 0},
		2: {"steam_id": 1002, "display_name": "B", "seat_id": 1},
		3: {"steam_id": 1003, "display_name": "C", "seat_id": 2},
		4: {"steam_id": 1004, "display_name": "D", "seat_id": 3},
	}
	var session: MatchSession = MatchAuthority.call("_build_session", roster)
	MatchAuthority.set("_session", session)
	MatchAuthority.set("_role_acknowledged", {1: true, 2: true})
	MatchAuthority.set("_heretic_targets", {1: 2, 2: 3})
	MatchAuthority.set("_healer_target_peer_id", 2)
	MatchAuthority.set("_inquisitor_target_peer_id", 2)
	MatchAuthority.set("_votes", {1: 2, 2: 3, 3: 4})

	assert_bool(MatchAuthority.call("_apply_peer_disconnect", 2)).is_true()
	assert_bool(session.get_player(2).alive).is_false()
	assert_bool(MatchAuthority.get("_role_acknowledged").has(2)).is_false()
	assert_bool(MatchAuthority.get("_heretic_targets").has(1)).is_false()
	assert_bool(MatchAuthority.get("_heretic_targets").has(2)).is_false()
	assert_int(int(MatchAuthority.get("_healer_target_peer_id"))).is_equal(0)
	assert_int(int(MatchAuthority.get("_inquisitor_target_peer_id"))).is_equal(0)
	assert_bool(MatchAuthority.get("_votes").has(1)).is_false()
	assert_bool(MatchAuthority.get("_votes").has(2)).is_false()
	assert_bool(MatchAuthority.get("_votes").has(3)).is_true()
