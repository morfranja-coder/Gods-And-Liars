extends SceneTree

func _initialize() -> void:
	var session := _build_ready_session()
	if session == null:
		return
	if not _validate_seats(session):
		return
	if not _validate_roles(session):
		return
	if not _validate_night_rule(session):
		return
	if not _validate_vote_rules(session):
		return

	print("GREEN: MVP core smoke tests passed")
	quit(0)

func _build_ready_session() -> MatchSession:
	var session := MatchSession.new(12345)
	for peer_id in range(1, 9):
		if not _require(
			session.add_player(peer_id, 1000 + peer_id, "Player %d" % peer_id),
			"could not add player %d" % peer_id,
		):
			return null
		session.get_player(peer_id).ready = true
	if not _require(
		session.can_start(),
		"eight ready players should be able to start",
	):
		return null
	if not _require(session.prepare_match(), "match preparation failed"):
		return null
	return session

func _validate_seats(session: MatchSession) -> bool:
	var used_seats: Dictionary = {}
	for player in session.players:
		if not _require(
			player.seat_id >= 0 and player.seat_id < TableLayout.SEAT_COUNT,
			"player received invalid seat %d" % player.seat_id,
		):
			return false
		if not _require(
			not used_seats.has(player.seat_id),
			"duplicate seat assignment",
		):
			return false
		used_seats[player.seat_id] = true
		var seat_position := TableLayout.seat_position(player.seat_id)
		if not _require(
			seat_position.length() > 2.0,
			"seat position is too close to origin",
		):
			return false
	return true

func _validate_roles(session: MatchSession) -> bool:
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
		return false
	if not _require(healers == 1, "expected exactly one healer"):
		return false
	if not _require(inquisitors == 1, "expected exactly one inquisitor"):
		return false
	return true

func _validate_night_rule(session: MatchSession) -> bool:
	var target := session.players[0]
	var result := NightResolver.resolve(
		session.players,
		target.peer_id,
		target.peer_id,
		0,
	)
	if not _require(
		result.killed_peer_id == 0,
		"healer should prevent the night kill",
	):
		return false
	return _require(target.alive, "protected target should remain alive")

func _validate_vote_rules(session: MatchSession) -> bool:
	var votes := {1: 3, 2: 3, 3: 2, 4: 3}
	if not _require(
		session.resolve_vote(votes) == 3,
		"unique vote winner should be peer 3",
	):
		return false

	var tie_votes := {1: 3, 2: 4}
	var tie_result := session.resolve_vote(tie_votes)
	return _require(
		tie_result in [3, 4],
		"tie should sacrifice one of the tied targets",
	)

func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	printerr("RED: Smoke test failed: %s" % message)
	quit(1)
	return false
