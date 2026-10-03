class_name QALocalMatchNightRulesTest
extends GdUnitTestSuite

func before_test() -> void:
	MatchAuthority.reset()
	GameManager.reset_match()

func after_test() -> void:
	MatchAuthority.reset()
	GameManager.reset_match()

func test_first_night_matches_runtime_exception() -> void:
	var session := _session_with_fixed_roles()
	var brains := _balanced_brains(session)
	var visited: Array[int] = []
	var night_state := {"healer_self_save_used": false}
	var trace := QALocalMatchController._run_night(
		session,
		brains,
		1,
		visited,
		night_state,
	)

	assert_bool(bool(trace.get("first_night", false))).is_true()
	assert_int(int(trace.get("heretic_decider", 0))).is_equal(1)
	assert_int(int(trace.get("heretic_target", 0))).is_greater(0)
	assert_int(int(trace.get("healer_target", 0))).is_equal(
		int(trace.get("heretic_target", 0))
	)
	assert_int(int(trace.get("inquisitor_target", -1))).is_equal(0)
	assert_int((trace.get("killed_peer_ids", []) as Array).size()).is_equal(0)
	assert_bool(bool(trace.get("kill_suppressed", false))).is_true()
	assert_bool(bool(trace.get("priest_saved", false))).is_true()
	assert_int(session.living_players().size()).is_equal(8)
	assert_bool(MatchAuthority.last_night_was_first).is_true()
	assert_int(MatchAuthority.last_night_killed_peer_ids.size()).is_equal(0)

func test_second_night_restores_role_actions_and_rotates_decider() -> void:
	var session := _session_with_fixed_roles()
	var brains := _balanced_brains(session)
	var visited: Array[int] = []
	var night_state := {"healer_self_save_used": false}
	var trace := QALocalMatchController._run_night(
		session,
		brains,
		2,
		visited,
		night_state,
	)

	assert_bool(bool(trace.get("first_night", true))).is_false()
	assert_int(int(trace.get("heretic_decider", 0))).is_equal(2)
	assert_int(int(trace.get("heretic_target", 0))).is_greater(0)
	assert_int(int(trace.get("healer_target", 0))).is_equal(3)
	assert_int(int(trace.get("inquisitor_target", 0))).is_greater(0)
	assert_bool(bool(trace.get("kill_suppressed", true))).is_false()
	assert_bool(bool(trace.get("healer_self_save_used", false))).is_true()
	assert_bool(bool(night_state.get("healer_self_save_used", false))).is_true()

func test_second_night_can_kill_when_priest_does_not_protect() -> void:
	var session := _session_with_fixed_roles()
	var brains := _balanced_brains(session)
	brains[3] = QABotBrain.new(QABotBrain.Profile.TIMEOUT)
	var visited: Array[int] = []
	var night_state := {"healer_self_save_used": false}
	var trace := QALocalMatchController._run_night(
		session,
		brains,
		2,
		visited,
		night_state,
	)

	assert_bool(bool(trace.get("kill_suppressed", true))).is_false()
	assert_int(int(trace.get("healer_target", -1))).is_equal(0)
	assert_int((trace.get("killed_peer_ids", []) as Array).size()).is_equal(1)
	assert_int(session.living_players().size()).is_equal(7)

func _session_with_fixed_roles() -> MatchSession:
	var session := MatchSession.new(1234)
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
			session.add_player(peer_id, 970000 + peer_id, "Night Bot %d" % peer_id)
		).is_true()
		var player := session.get_player(peer_id)
		player.role = roles[peer_id - 1]
		player.ready = true
		MatchAuthority.public_alive_by_peer[peer_id] = true
	MatchAuthority.set("_session", session)
	MatchAuthority._receive_private_role(int(session.get_player(1).role))
	return session

func _balanced_brains(session: MatchSession) -> Dictionary:
	var brains: Dictionary = {}
	for player in session.players:
		brains[player.peer_id] = QABotBrain.new(QABotBrain.Profile.BALANCED)
	return brains
