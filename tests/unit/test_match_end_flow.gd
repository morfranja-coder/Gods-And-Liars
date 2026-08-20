class_name MatchEndFlowTest
extends GdUnitTestSuite

func test_faithful_win_when_no_heretics_alive() -> void:
	var session := _session_with_roles([
		PlayerState.Role.HERETIC,
		PlayerState.Role.FAITHFUL,
		PlayerState.Role.HEALER,
		PlayerState.Role.INQUISITOR,
	])
	session.get_player(1).alive = false
	assert_str(str(session.winner())).is_equal("faithful")

func test_heretics_win_at_parity() -> void:
	var session := _session_with_roles([
		PlayerState.Role.HERETIC,
		PlayerState.Role.FAITHFUL,
		PlayerState.Role.HEALER,
		PlayerState.Role.INQUISITOR,
	])
	session.get_player(3).alive = false
	session.get_player(4).alive = false
	assert_str(str(session.winner())).is_equal("heretics")

func test_no_winner_while_faithful_side_has_majority() -> void:
	var session := _session_with_roles([
		PlayerState.Role.HERETIC,
		PlayerState.Role.FAITHFUL,
		PlayerState.Role.HEALER,
		PlayerState.Role.INQUISITOR,
	])
	assert_str(str(session.winner())).is_equal("")

func _session_with_roles(roles: Array[PlayerState.Role]) -> MatchSession:
	var session := MatchSession.new(1)
	for index in roles.size():
		var peer_id := index + 1
		session.add_player(peer_id, 9000 + peer_id, "P%d" % peer_id)
		session.get_player(peer_id).role = roles[index]
	return session
