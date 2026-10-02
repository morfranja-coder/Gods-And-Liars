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
	assert_str(MatchAuthority.role_title()).is_equal("Sacerdote")
	assert_bool(MatchAuthority.role_description().contains("Protegé")).is_true()

func test_heretic_receives_only_private_teammate_identity() -> void:
	MatchAuthority._receive_private_role(int(PlayerState.Role.HERETIC))
	MatchAuthority._receive_private_heretic_teammate(2, "P2")
	assert_int(MatchAuthority.local_heretic_teammate_peer_id).is_equal(2)
	assert_str(MatchAuthority.local_heretic_teammate_name).is_equal("P2")
	assert_bool(MatchAuthority.role_description().contains("P2")).is_true()
	assert_bool(MatchAuthority.get("_session") == null).is_true()

func test_non_heretic_ignores_private_teammate_identity() -> void:
	MatchAuthority._receive_private_role(int(PlayerState.Role.HEALER))
	MatchAuthority._receive_private_heretic_teammate(2, "P2")
	assert_int(MatchAuthority.local_heretic_teammate_peer_id).is_equal(0)
	assert_str(MatchAuthority.local_heretic_teammate_name).is_empty()

func test_heretic_decider_recipient_list_excludes_non_heretics_and_dead_players() -> void:
	var session: MatchSession = MatchAuthority.call("_build_session", _eight_player_roster())
	assert_bool(session != null).is_true()
	session.get_player(1).role = PlayerState.Role.HERETIC
	session.get_player(2).role = PlayerState.Role.HERETIC
	session.get_player(3).role = PlayerState.Role.HEALER
	session.get_player(4).role = PlayerState.Role.HERETIC
	session.get_player(4).alive = false
	MatchAuthority.set("_session", session)

	var recipients: Array[int] = MatchAuthority.call("_heretic_decider_recipients")
	assert_int(recipients.size()).is_equal(2)
	assert_bool(recipients.has(1)).is_true()
	assert_bool(recipients.has(2)).is_true()
	assert_bool(recipients.has(3)).is_false()
	assert_bool(recipients.has(4)).is_false()

func test_non_heretic_rejects_private_heretic_decider() -> void:
	MatchAuthority._receive_private_role(int(PlayerState.Role.FAITHFUL))
	MatchAuthority._receive_private_heretic_decider(2)
	assert_int(MatchAuthority.current_heretic_decider_peer_id).is_equal(0)

func test_heretic_accepts_private_heretic_decider() -> void:
	MatchAuthority._receive_private_role(int(PlayerState.Role.HERETIC))
	MatchAuthority._receive_private_heretic_decider(2)
	assert_int(MatchAuthority.current_heretic_decider_peer_id).is_equal(2)

func test_host_resolves_only_the_other_heretic_as_teammate() -> void:
	var session: MatchSession = MatchAuthority.call("_build_session", _eight_player_roster())
	assert_bool(session != null).is_true()
	session.get_player(1).role = PlayerState.Role.HERETIC
	session.get_player(2).role = PlayerState.Role.HERETIC
	session.get_player(3).role = PlayerState.Role.HEALER
	MatchAuthority.set("_session", session)
	var teammate: PlayerState = MatchAuthority.call("_heretic_teammate_for", 1)
	assert_bool(teammate != null).is_true()
	assert_int(teammate.peer_id).is_equal(2)
	assert_bool(MatchAuthority.call("_heretic_teammate_for", 3) == null).is_true()

func test_build_session_preserves_authoritative_seats() -> void:
	var roster := _eight_player_roster()
	var session: MatchSession = MatchAuthority.call("_build_session", roster)
	assert_bool(session != null).is_true()
	assert_int(session.get_player(1).seat_id).is_equal(0)
	assert_int(session.get_player(4).seat_id).is_equal(3)
	assert_int(session.get_player(8).seat_id).is_equal(7)

func test_phase_sync_updates_round_number() -> void:
	MatchAuthority._sync_phase(int(GameManager.MatchPhase.DAY_DISCUSSION), 3)
	assert_int(int(GameManager.phase)).is_equal(int(GameManager.MatchPhase.DAY_DISCUSSION))
	assert_int(GameManager.round_number).is_equal(3)

func test_disconnected_heretic_decider_is_reassigned_without_restarting_phase() -> void:
	var session: MatchSession = MatchAuthority.call("_build_session", _eight_player_roster())
	assert_bool(session != null).is_true()
	for player in session.players:
		player.role = PlayerState.Role.FAITHFUL
	session.get_player(1).role = PlayerState.Role.HERETIC
	session.get_player(2).role = PlayerState.Role.HERETIC
	MatchAuthority.set("_session", session)
	MatchAuthority.current_heretic_decider_peer_id = 1
	MatchAuthority.set("_heretic_targets", {1: 5})
	GameManager.round_number = 1
	GameManager.set_phase(GameManager.MatchPhase.HERETIC_ACTION)

	assert_bool(MatchAuthority.call("_apply_peer_disconnect", 1)).is_true()
	MatchAuthority.call("_resume_after_disconnect", 1)

	assert_int(MatchAuthority.current_heretic_decider_peer_id).is_equal(2)
	assert_bool(MatchAuthority.get("_heretic_targets").is_empty()).is_true()
	assert_int(int(GameManager.phase)).is_equal(int(GameManager.MatchPhase.HERETIC_ACTION))


func test_non_decider_heretic_disconnect_keeps_current_decider() -> void:
	var session: MatchSession = MatchAuthority.call("_build_session", _eight_player_roster())
	assert_bool(session != null).is_true()
	for player in session.players:
		player.role = PlayerState.Role.FAITHFUL
	session.get_player(1).role = PlayerState.Role.HERETIC
	session.get_player(2).role = PlayerState.Role.HERETIC
	MatchAuthority.set("_session", session)
	MatchAuthority.current_heretic_decider_peer_id = 1
	GameManager.round_number = 1
	GameManager.set_phase(GameManager.MatchPhase.HERETIC_ACTION)

	assert_bool(MatchAuthority.call("_apply_peer_disconnect", 2)).is_true()
	MatchAuthority.call("_resume_after_disconnect", 2)

	assert_int(MatchAuthority.current_heretic_decider_peer_id).is_equal(1)
	assert_int(int(GameManager.phase)).is_equal(int(GameManager.MatchPhase.HERETIC_ACTION))


func test_vote_state_is_public_and_voter_cannot_replace_vote() -> void:
	var session: MatchSession = MatchAuthority.call("_build_session", _eight_player_roster())
	assert_bool(session != null).is_true()
	MatchAuthority.set("_session", session)
	MatchAuthority.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	for player in session.players:
		player.alive = true
	GameManager.set_phase(GameManager.MatchPhase.VOTING)

	MatchAuthority.call("_server_submit_vote", 1, 2)
	assert_int(int(MatchAuthority.get("_votes").get(1, 0))).is_equal(2)
	assert_int(int(MatchAuthority.public_votes.get(1, 0))).is_equal(2)
	MatchAuthority.call("_server_submit_vote", 1, 3)
	assert_int(int(MatchAuthority.get("_votes").get(1, 0))).is_equal(2)
	assert_int(int(MatchAuthority.public_votes.get(1, 0))).is_equal(2)
	MatchAuthority.multiplayer.multiplayer_peer = null


func test_disconnect_marks_session_player_dead_and_clears_pending_actions() -> void:
	var session: MatchSession = MatchAuthority.call("_build_session", _eight_player_roster())
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

func _eight_player_roster() -> Dictionary:
	var roster: Dictionary = {}
	for peer_id in range(1, QuickMatchRules.TARGET_PLAYERS + 1):
		roster[peer_id] = {
			"steam_id": 1000 + peer_id,
			"display_name": "P%d" % peer_id,
			"seat_id": peer_id - 1,
		}
	return roster
