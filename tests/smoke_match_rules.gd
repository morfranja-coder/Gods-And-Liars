extends SceneTree

func _initialize() -> void:
	var session := MatchSession.new(12345)
	for peer_id in range(1, 9):
		if not _require(
			session.add_player(peer_id, 1000 + peer_id, "Player %d" % peer_id),
			"could not add player %d" % peer_id,
		):
			return
		session.get_player(peer_id).ready = true
	if not _require(session.can_start(), "eight ready players should be able to start"):
		return
	if not _require(session.prepare_match(), "match preparation failed"):
		return

	var used_seats: Dictionary = {}
	for player in session.players:
		if not _require(
			player.seat_id >= 0 and player.seat_id < TableLayout.SEAT_COUNT,
			"player received invalid seat %d" % player.seat_id,
		):
			return
		if not _require(not used_seats.has(player.seat_id), "duplicate seat assignment"):
			return
		used_seats[player.seat_id] = true
		var seat_position := TableLayout.seat_position(player.seat_id)
		if not _require(seat_position.length() > 2.0, "seat position is too close to origin"):
			return

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
	if not _require(heretics == 2, "expected exactly two heretics"):
		return
	if not _require(healers == 1, "expected exactly one healer"):
		return
	if not _require(inquisitors == 1, "expected exactly one inquisitor"):
		return

	var target := session.players[0]
	var result := NightResolver.resolve(session.players, target.peer_id, target.peer_id, 0)
	if not _require(result.killed_peer_id == 0, "healer should prevent the night kill"):
		return
	if not _require(target.alive, "protected target should remain alive"):
		return

	var votes := {1: 3, 2: 3, 3: 2, 4: 3}
	if not _require(session.resolve_vote(votes) == 3, "unique vote winner should be peer 3"):
		return

	var tie_votes := {1: 3, 2: 4}
	var tie_result := session.resolve_vote(tie_votes)
	if not _require(tie_result in [3, 4], "tie should sacrifice one of the tied targets"):
		return

	print("GREEN: MVP core smoke tests passed")
	quit(0)

func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	printerr("RED: Smoke test failed: %s" % message)
	quit(1)
	return false
