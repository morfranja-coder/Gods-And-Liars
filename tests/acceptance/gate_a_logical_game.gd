extends SceneTree

const SEED_COUNT := 1000
const REMATCH_SEED_COUNT := 100
const EXPECTED_PLAYERS := 8
const EXPECTED_HERETICS := 2
const EXPECTED_FAITHFUL := 4
const EXPECTED_HEALERS := 1
const EXPECTED_INQUISITORS := 1

var _failures: Array[String] = []

func _init() -> void:
	_run_gate()
	if _failures.is_empty():
		print(
			"GREEN: Gate A logical acceptance passed (%d full matches, %d rematch checks)."
			% [SEED_COUNT, REMATCH_SEED_COUNT]
		)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("RED: Gate A logical acceptance failed with %d issue(s)." % _failures.size())
	quit(1)

func _run_gate() -> void:
	for seed_value in range(1, SEED_COUNT + 1):
		_verify_initial_session(seed_value)
		_verify_full_match(seed_value)
	for seed_value in range(1, REMATCH_SEED_COUNT + 1):
		_verify_rematch(seed_value)

func _verify_initial_session(seed_value: int) -> void:
	var session := _prepared_session(seed_value)
	if session == null:
		_fail("seed %d: could not prepare exact-eight session" % seed_value)
		return
	if session.players.size() != EXPECTED_PLAYERS:
		_fail("seed %d: expected %d players, got %d" % [seed_value, EXPECTED_PLAYERS, session.players.size()])
		return
	var seats: Dictionary = {}
	var role_counts := {
		PlayerState.Role.HERETIC: 0,
		PlayerState.Role.FAITHFUL: 0,
		PlayerState.Role.HEALER: 0,
		PlayerState.Role.INQUISITOR: 0,
	}
	for player in session.players:
		if player.seat_id < 0 or player.seat_id >= EXPECTED_PLAYERS:
			_fail("seed %d: invalid seat %d for peer %d" % [seed_value, player.seat_id, player.peer_id])
		if seats.has(player.seat_id):
			_fail("seed %d: duplicate seat %d" % [seed_value, player.seat_id])
		seats[player.seat_id] = true
		if not role_counts.has(player.role):
			_fail("seed %d: unexpected role %d" % [seed_value, player.role])
		else:
			role_counts[player.role] = int(role_counts[player.role]) + 1
		if not player.alive:
			_fail("seed %d: player %d starts dead" % [seed_value, player.peer_id])
	if seats.size() != EXPECTED_PLAYERS:
		_fail("seed %d: expected %d unique seats, got %d" % [seed_value, EXPECTED_PLAYERS, seats.size()])
	_check_role_count(seed_value, role_counts, PlayerState.Role.HERETIC, EXPECTED_HERETICS, "Heretics")
	_check_role_count(seed_value, role_counts, PlayerState.Role.FAITHFUL, EXPECTED_FAITHFUL, "Faithful")
	_check_role_count(seed_value, role_counts, PlayerState.Role.HEALER, EXPECTED_HEALERS, "Healers")
	_check_role_count(seed_value, role_counts, PlayerState.Role.INQUISITOR, EXPECTED_INQUISITORS, "Inquisitors")

func _verify_full_match(seed_value: int) -> void:
	var result := QAMatchSimulator.run(seed_value)
	if not bool(result.get("completed", false)):
		_fail("seed %d: match did not complete: %s" % [seed_value, result])
		return
	if int(result.get("players", 0)) != EXPECTED_PLAYERS:
		_fail("seed %d: completed with wrong player count: %s" % [seed_value, result])
	var winner := str(result.get("winner", ""))
	if winner not in ["faithful", "heretics"]:
		_fail("seed %d: invalid winner '%s'" % [seed_value, winner])
	var rounds := int(result.get("rounds", QAMatchSimulator.DEFAULT_MAX_ROUNDS + 1))
	if rounds <= 0 or rounds > QAMatchSimulator.DEFAULT_MAX_ROUNDS:
		_fail("seed %d: invalid round count %d" % [seed_value, rounds])

func _verify_rematch(seed_value: int) -> void:
	var session := _prepared_session(100000 + seed_value)
	if session == null:
		_fail("rematch seed %d: initial prepare failed" % seed_value)
		return
	var original_seats: Dictionary = {}
	for player in session.players:
		original_seats[player.peer_id] = player.seat_id
		player.alive = false
		player.selected_target_peer_id = 999
		player.vote_target_peer_id = 999
	if not session.prepare_match():
		_fail("rematch seed %d: second prepare failed" % seed_value)
		return
	var role_counts := {
		PlayerState.Role.HERETIC: 0,
		PlayerState.Role.FAITHFUL: 0,
		PlayerState.Role.HEALER: 0,
		PlayerState.Role.INQUISITOR: 0,
	}
	for player in session.players:
		if int(original_seats.get(player.peer_id, -1)) != player.seat_id:
			_fail("rematch seed %d: peer %d changed seat" % [seed_value, player.peer_id])
		if not player.alive:
			_fail("rematch seed %d: peer %d was not revived" % [seed_value, player.peer_id])
		if player.selected_target_peer_id != 0 or player.vote_target_peer_id != 0:
			_fail("rematch seed %d: peer %d retained action state" % [seed_value, player.peer_id])
		if role_counts.has(player.role):
			role_counts[player.role] = int(role_counts[player.role]) + 1
		else:
			_fail("rematch seed %d: peer %d has invalid role %d" % [seed_value, player.peer_id, player.role])
	_check_role_count(seed_value, role_counts, PlayerState.Role.HERETIC, EXPECTED_HERETICS, "rematch Heretics")
	_check_role_count(seed_value, role_counts, PlayerState.Role.FAITHFUL, EXPECTED_FAITHFUL, "rematch Faithful")
	_check_role_count(seed_value, role_counts, PlayerState.Role.HEALER, EXPECTED_HEALERS, "rematch Healers")
	_check_role_count(seed_value, role_counts, PlayerState.Role.INQUISITOR, EXPECTED_INQUISITORS, "rematch Inquisitors")

func _prepared_session(seed_value: int) -> MatchSession:
	var session := MatchSession.new(seed_value)
	for peer_id in range(1, EXPECTED_PLAYERS + 1):
		if not session.add_player(peer_id, 950000 + peer_id, "Gate A Bot %d" % peer_id):
			return null
		var player := session.get_player(peer_id)
		player.ready = true
	if not session.can_start() or not session.prepare_match():
		return null
	return session

func _check_role_count(
	seed_value: int,
	role_counts: Dictionary,
	role: PlayerState.Role,
	expected: int,
	label: String,
) -> void:
	var actual := int(role_counts.get(role, 0))
	if actual != expected:
		_fail("seed %d: expected %d %s, got %d" % [seed_value, expected, label, actual])

func _fail(message: String) -> void:
	if _failures.size() < 100:
		_failures.append(message)
