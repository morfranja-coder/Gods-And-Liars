class_name MatchAuthorityDisconnectMatrixTest
extends GdUnitTestSuite

func before_test() -> void:
	NetworkManager.reset()
	MatchAuthority.reset()
	GameManager.reset_match()
	MatchAuthority.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	NetworkManager.is_host = true

func after_test() -> void:
	MatchAuthority.multiplayer.multiplayer_peer = null
	NetworkManager.reset()
	MatchAuthority.reset()
	GameManager.reset_match()

func test_dead_heretic_cannot_submit_night_action() -> void:
	var session := _fixed_session()
	MatchAuthority.set("_session", session)
	MatchAuthority.current_heretic_decider_peer_id = 1
	GameManager.round_number = 2
	GameManager.set_phase(GameManager.MatchPhase.HERETIC_ACTION)
	session.get_player(1).alive = false

	MatchAuthority.call("_server_submit_night_action", 1, 5)

	assert_bool((MatchAuthority.get("_heretic_targets") as Dictionary).is_empty()).is_true()

func test_dead_target_cannot_receive_night_action() -> void:
	var session := _fixed_session()
	MatchAuthority.set("_session", session)
	MatchAuthority.current_heretic_decider_peer_id = 1
	GameManager.round_number = 2
	GameManager.set_phase(GameManager.MatchPhase.HERETIC_ACTION)
	session.get_player(5).alive = false

	MatchAuthority.call("_server_submit_night_action", 1, 5)

	assert_bool((MatchAuthority.get("_heretic_targets") as Dictionary).is_empty()).is_true()

func test_dead_voter_and_dead_target_are_rejected() -> void:
	var session := _fixed_session()
	MatchAuthority.set("_session", session)
	GameManager.set_phase(GameManager.MatchPhase.VOTING)
	session.get_player(2).alive = false

	MatchAuthority.call("_server_submit_vote", 2, 3)
	MatchAuthority.call("_server_submit_vote", 1, 2)

	assert_bool((MatchAuthority.get("_votes") as Dictionary).is_empty()).is_true()

func test_disconnect_during_voting_removes_own_and_targeted_votes() -> void:
	var session := _fixed_session()
	MatchAuthority.set("_session", session)
	MatchAuthority.set("_votes", {1: 2, 2: 3, 3: 4})
	MatchAuthority.public_votes = {1: 2, 2: 3, 3: 4}
	GameManager.set_phase(GameManager.MatchPhase.VOTING)

	assert_bool(MatchAuthority.call("_apply_peer_disconnect", 2)).is_true()
	MatchAuthority.call("_resume_after_disconnect", 2)

	var votes: Dictionary = MatchAuthority.get("_votes")
	assert_bool(votes.has(1)).is_false()
	assert_bool(votes.has(2)).is_false()
	assert_int(int(votes.get(3, 0))).is_equal(4)
	assert_bool(MatchAuthority.public_votes.has(1)).is_false()
	assert_bool(MatchAuthority.public_votes.has(2)).is_false()
	assert_int(int(MatchAuthority.public_votes.get(3, 0))).is_equal(4)

func test_healer_disconnect_advances_when_no_healer_remains() -> void:
	var session := _fixed_session()
	MatchAuthority.set("_session", session)
	GameManager.round_number = 2
	GameManager.set_phase(GameManager.MatchPhase.HEALER_ACTION)

	assert_bool(MatchAuthority.call("_apply_peer_disconnect", 3)).is_true()
	MatchAuthority.call("_resume_after_disconnect", 3)

	assert_int(int(GameManager.phase)).is_equal(
		int(GameManager.MatchPhase.INQUISITOR_ACTION)
	)

func test_inquisitor_disconnect_advances_when_no_inquisitor_remains() -> void:
	var session := _fixed_session()
	MatchAuthority.set("_session", session)
	GameManager.round_number = 2
	GameManager.set_phase(GameManager.MatchPhase.INQUISITOR_ACTION)

	assert_bool(MatchAuthority.call("_apply_peer_disconnect", 4)).is_true()
	MatchAuthority.call("_resume_after_disconnect", 4)

	assert_int(int(GameManager.phase)).is_equal(
		int(GameManager.MatchPhase.NIGHT_RESOLUTION)
	)

func _fixed_session() -> MatchSession:
	var session := MatchSession.new(12345)
	var roles: Array[PlayerState.Role] = [
		PlayerState.Role.HERETIC,
		PlayerState.Role.HERETIC,
		PlayerState.Role.HEALER,
		PlayerState.Role.INQUISITOR,
		PlayerState.Role.FAITHFUL,
		PlayerState.Role.FAITHFUL,
		PlayerState.Role.FAITHFUL,
		PlayerState.Role.FAITHFUL,
	]
	for peer_id in range(1, 9):
		assert_bool(
			session.add_player(peer_id, 960000 + peer_id, "Disconnect P%d" % peer_id)
		).is_true()
		var player := session.get_player(peer_id)
		player.role = roles[peer_id - 1]
		player.ready = true
		MatchAuthority.public_alive_by_peer[peer_id] = true
	return session
