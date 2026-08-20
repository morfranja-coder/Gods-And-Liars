extends SceneTree

func _initialize() -> void:
	var session := MatchSession.new(12345)
	for peer_id in range(1, 9):
		assert(session.add_player(peer_id, 1000 + peer_id, "Player %d" % peer_id))
		session.get_player(peer_id).ready = true
	assert(session.can_start())
	assert(session.prepare_match())

	var used_seats: Dictionary = {}
	for player in session.players:
		assert(player.seat_id >= 0 and player.seat_id < TableLayout.SEAT_COUNT)
		assert(not used_seats.has(player.seat_id))
		used_seats[player.seat_id] = true
		var seat_position := TableLayout.seat_position(player.seat_id)
		assert(seat_position.length() > 2.0)

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
	assert(heretics == 2)
	assert(healers == 1)
	assert(inquisitors == 1)

	var target := session.players[0]
	var result := NightResolver.resolve(session.players, target.peer_id, target.peer_id, 0)
	assert(result.killed_peer_id == 0)
	assert(target.alive)

	var votes := {1: 3, 2: 3, 3: 2, 4: 3}
	assert(session.resolve_vote(votes) == 3)

	var tie_votes := {1: 3, 2: 4}
	assert(session.resolve_vote(tie_votes) == 0)

	print("MVP core smoke tests passed")
	quit(0)
