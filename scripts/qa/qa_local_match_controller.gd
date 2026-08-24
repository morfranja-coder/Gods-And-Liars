class_name QALocalMatchController
extends RefCounted

const BOT_COUNT := QuickMatchRules.TARGET_PLAYERS
const DEFAULT_MAX_ROUNDS := 40

static func run(seed_value: int = 42, max_rounds: int = DEFAULT_MAX_ROUNDS) -> Dictionary:
	var session := MatchSession.new(seed_value)
	for peer_id in range(1, BOT_COUNT + 1):
		if not session.add_player(peer_id, 980000 + peer_id, "Gate C Bot %d" % peer_id):
			return {"completed": false, "reason": "add_player_failed"}
		var player := session.get_player(peer_id)
		player.ready = true
	if not session.prepare_match():
		return {"completed": false, "reason": "prepare_match_failed"}

	MatchAuthority.set("_session", session)
	MatchAuthority.public_alive_by_peer.clear()
	for player in session.players:
		MatchAuthority.public_alive_by_peer[player.peer_id] = true
	var local_player := session.get_player(1)
	MatchAuthority._receive_private_role(int(local_player.role))
	MatchAuthority._sync_phase(int(GameManager.MatchPhase.ROLE_REVEAL), 1)

	var brains: Dictionary = {}
	for player in session.players:
		brains[player.peer_id] = QABotBrain.new(QABotBrain.Profile.BALANCED)

	var visited_phases: Array[int] = [int(GameManager.MatchPhase.ROLE_REVEAL)]
	var rounds := 0
	while rounds < max_rounds:
		rounds += 1
		_run_night(session, brains, rounds, visited_phases)
		var winner := session.winner()
		if not winner.is_empty():
			_finish(winner, visited_phases)
			return _result(session, winner, rounds, visited_phases, true)

		_sync_phase(GameManager.MatchPhase.DAY_DISCUSSION, rounds, visited_phases)
		_sync_phase(GameManager.MatchPhase.VOTING, rounds, visited_phases)
		_run_vote(session, brains, rounds, visited_phases)
		winner = session.winner()
		if not winner.is_empty():
			_finish(winner, visited_phases)
			return _result(session, winner, rounds, visited_phases, true)

	return _result(session, session.winner(), rounds, visited_phases, false)

static func _run_night(
	session: MatchSession,
	brains: Dictionary,
	round_value: int,
	visited_phases: Array[int],
) -> void:
	_sync_phase(GameManager.MatchPhase.NIGHT_START, round_value, visited_phases)
	_sync_phase(GameManager.MatchPhase.HERETIC_ACTION, round_value, visited_phases)
	var heretic_targets: Array[int] = []
	for player in session.players:
		if not player.alive or player.role != PlayerState.Role.HERETIC:
			continue
		var brain: QABotBrain = brains[player.peer_id]
		var target := brain.choose_night_target(session.players, player.peer_id)
		if target > 0:
			heretic_targets.append(target)

	_sync_phase(GameManager.MatchPhase.HEALER_ACTION, round_value, visited_phases)
	var healer_target := _night_target_for_role(session, brains, PlayerState.Role.HEALER)
	_sync_phase(GameManager.MatchPhase.INQUISITOR_ACTION, round_value, visited_phases)
	var inquisitor_target := _night_target_for_role(session, brains, PlayerState.Role.INQUISITOR)
	_sync_phase(GameManager.MatchPhase.NIGHT_RESOLUTION, round_value, visited_phases)
	var result := NightResolver.resolve_many(
		session.players,
		heretic_targets,
		healer_target,
		inquisitor_target,
	)
	MatchAuthority._sync_night_resolution(result.killed_peer_ids)
	if result.investigation_target_peer_id > 0:
		MatchAuthority._receive_private_investigation(
			result.investigation_target_peer_id,
			result.investigation_is_heretic,
		)
	_sync_phase(GameManager.MatchPhase.WIN_CHECK, round_value, visited_phases)

static func _run_vote(
	session: MatchSession,
	brains: Dictionary,
	round_value: int,
	visited_phases: Array[int],
) -> void:
	var votes: Dictionary = {}
	for player in session.players:
		if not player.alive:
			continue
		var brain: QABotBrain = brains[player.peer_id]
		var target := brain.choose_vote_target(session.players, player.peer_id)
		if target > 0:
			votes[player.peer_id] = target
	var sacrificed_peer_id := VoteRules.resolve(session.players, votes)
	_sync_phase(GameManager.MatchPhase.SACRIFICE, round_value, visited_phases)
	if sacrificed_peer_id > 0:
		session.sacrifice(sacrificed_peer_id)
		MatchAuthority._sync_sacrifice(sacrificed_peer_id, false)
	else:
		MatchAuthority._sync_sacrifice(0, true)
	_sync_phase(GameManager.MatchPhase.WIN_CHECK, round_value, visited_phases)

static func _night_target_for_role(
	session: MatchSession,
	brains: Dictionary,
	role: PlayerState.Role,
) -> int:
	for player in session.players:
		if player.alive and player.role == role:
			var brain: QABotBrain = brains[player.peer_id]
			return brain.choose_night_target(session.players, player.peer_id)
	return 0

static func _sync_phase(
	phase_value: GameManager.MatchPhase,
	round_value: int,
	visited_phases: Array[int],
) -> void:
	MatchAuthority._sync_phase(int(phase_value), round_value)
	visited_phases.append(int(phase_value))

static func _finish(winner: StringName, visited_phases: Array[int]) -> void:
	MatchAuthority._sync_match_end(str(winner))
	visited_phases.append(int(GameManager.MatchPhase.MATCH_END))

static func _result(
	session: MatchSession,
	winner: StringName,
	rounds: int,
	visited_phases: Array[int],
	completed: bool,
) -> Dictionary:
	return {
		"completed": completed,
		"winner": str(winner),
		"rounds": rounds,
		"players": session.players.size(),
		"living": session.living_players().size(),
		"visited_phases": visited_phases.duplicate(),
	}
