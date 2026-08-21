class_name QAMatchSimulator
extends RefCounted

const BOT_COUNT := QuickMatchRules.TARGET_PLAYERS
const DEFAULT_MAX_ROUNDS := 40

static func run(seed_value: int, max_rounds: int = DEFAULT_MAX_ROUNDS) -> Dictionary:
	var session := MatchSession.new(seed_value)
	for index in range(BOT_COUNT):
		var peer_id := index + 1
		if not session.add_player(peer_id, 900000 + peer_id, "QA Bot %d" % peer_id):
			return {"completed": false, "reason": "add_player_failed", "rounds": 0}
		var player := session.get_player(peer_id)
		player.ready = true
	if not session.prepare_match():
		return {"completed": false, "reason": "prepare_match_failed", "rounds": 0}

	var brains: Dictionary = {}
	for player in session.players:
		brains[player.peer_id] = QABotBrain.new(QABotBrain.Profile.BALANCED)

	var rounds := 0
	while rounds < max_rounds:
		var current_winner := session.winner()
		if not current_winner.is_empty():
			return _result(session, current_winner, rounds, true)
		rounds += 1
		_run_night(session, brains)
		current_winner = session.winner()
		if not current_winner.is_empty():
			return _result(session, current_winner, rounds, true)
		_run_vote(session, brains)
		current_winner = session.winner()
		if not current_winner.is_empty():
			return _result(session, current_winner, rounds, true)

	return _result(session, session.winner(), rounds, false)

static func _run_night(session: MatchSession, brains: Dictionary) -> void:
	var heretic_targets: Array[int] = []
	var healer_target := 0
	var inquisitor_target := 0
	for player in session.players:
		if not player.alive:
			continue
		var brain: QABotBrain = brains[player.peer_id]
		var target := brain.choose_night_target(session.players, player.peer_id)
		match player.role:
			PlayerState.Role.HERETIC:
				if target != 0:
					heretic_targets.append(target)
			PlayerState.Role.HEALER:
				healer_target = target
			PlayerState.Role.INQUISITOR:
				inquisitor_target = target
	NightResolver.resolve_many(
		session.players,
		heretic_targets,
		healer_target,
		inquisitor_target,
	)

static func _run_vote(session: MatchSession, brains: Dictionary) -> void:
	var votes: Dictionary = {}
	for player in session.players:
		if not player.alive:
			continue
		var brain: QABotBrain = brains[player.peer_id]
		var target := brain.choose_vote_target(session.players, player.peer_id)
		if target != 0:
			votes[player.peer_id] = target
	var sacrificed_peer_id := VoteRules.resolve(session.players, votes)
	if sacrificed_peer_id > 0:
		session.sacrifice(sacrificed_peer_id)

static func _result(
	session: MatchSession,
	winner_name: StringName,
	rounds: int,
	completed: bool,
) -> Dictionary:
	return {
		"completed": completed,
		"winner": str(winner_name),
		"rounds": rounds,
		"living": session.living_players().size(),
		"players": session.players.size(),
	}
