class_name MatchSessionTest
extends GdUnitTestSuite

func test_eight_players_get_expected_core_roles() -> void:
	var session := MatchSession.new(12345)
	for peer_id in range(1, 9):
		assert_bool(session.add_player(peer_id, 1000 + peer_id, "Player %d" % peer_id)).is_true()
	assert_bool(session.prepare_match()).is_true()

	var heretics := 0
	var healers := 0
	var inquisitors := 0
	for player in session.players:
		match player.role:
			PlayerState.Role.HERETIC:
				heretics += 1
			PlayerState.Role.HEALER:
				healers += 1
			PlayerState.Role.INQUISITOR:
				inquisitors += 1

	assert_int(heretics).is_equal(2)
	assert_int(healers).is_equal(1)
	assert_int(inquisitors).is_equal(1)

func test_seven_players_cannot_start_current_mafia_match() -> void:
	var session := MatchSession.new(2)
	for peer_id in range(1, 8):
		assert_bool(session.add_player(peer_id, 4000 + peer_id, "P%d" % peer_id)).is_true()
		session.get_player(peer_id).ready = true
	assert_bool(session.can_start()).is_false()
	assert_bool(session.prepare_match()).is_false()

func test_eight_ready_players_can_start_and_ninth_is_rejected() -> void:
	var session := MatchSession.new(3)
	for peer_id in range(1, 9):
		assert_bool(session.add_player(peer_id, 5000 + peer_id, "P%d" % peer_id)).is_true()
		session.get_player(peer_id).ready = true
	assert_bool(session.can_start()).is_true()
	assert_bool(session.add_player(9, 5009, "P9")).is_false()

func test_vote_tie_returns_no_sacrifice() -> void:
	var session := MatchSession.new(7)
	for peer_id in range(1, 5):
		assert_bool(session.add_player(peer_id, 2000 + peer_id, "Player %d" % peer_id)).is_true()

	var votes := {1: 3, 2: 4}
	assert_int(session.resolve_vote(votes)).is_equal(0)

func test_healer_prevents_night_kill() -> void:
	var session := MatchSession.new(11)
	for peer_id in range(1, 5):
		assert_bool(session.add_player(peer_id, 3000 + peer_id, "Player %d" % peer_id)).is_true()

	var target := session.players[0]
	var result := NightResolver.resolve(session.players, target.peer_id, target.peer_id, 0)
	assert_int(int(result.killed_peer_id)).is_equal(0)
	assert_bool(target.alive).is_true()
