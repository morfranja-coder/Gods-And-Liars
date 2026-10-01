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
	var night_state := {"healer_self_save_used": false}
	while rounds < max_rounds:
		var current_winner := session.winner()
		if not current_winner.is_empty():
			return _result(session, current_winner, rounds, true)
		rounds += 1
		_run_night(session, brains, rounds, night_state)
		current_winner = session.winner()
		if not current_winner.is_empty():
			return _result(session, current_winner, rounds, true)
		_run_vote(session, brains)
		current_winner = session.winner()
		if not current_winner.is_empty():
			return _result(session, current_winner, rounds, true)

	return _result(session, session.winner(), rounds, false)

static func _run_night(
	session: MatchSession,
	brains: Dictionary,
	round_number: int,
	night_state: Dictionary,
) -> void:
	var decider_peer_id := NightRoundRules.choose_heretic_decider(
		session.players,
		round_number,
	)
	var heretic_target := _choose_role_target(
		session,
		brains,
		PlayerState.Role.HERETIC,
		round_number,
		decider_peer_id,
		bool(night_state.get("healer_self_save_used", false)),
	)
	var healer_target := 0
	var inquisitor_target := 0
	if NightRoundRules.is_first_night(round_number):
		if heretic_target > 0 and _living_role_peer_id(
			session.players,
			PlayerState.Role.HEALER,
		) > 0:
			healer_target = heretic_target
	else:
		healer_target = _choose_role_target(
			session,
			brains,
			PlayerState.Role.HEALER,
			round_number,
			decider_peer_id,
			bool(night_state.get("healer_self_save_used", false)),
		)
		inquisitor_target = _choose_role_target(
			session,
			brains,
			PlayerState.Role.INQUISITOR,
			round_number,
			decider_peer_id,
			bool(night_state.get("healer_self_save_used", false)),
		)
		var healer_peer_id := _living_role_peer_id(
			session.players,
			PlayerState.Role.HEALER,
		)
		if healer_peer_id > 0 and healer_target == healer_peer_id:
			night_state["healer_self_save_used"] = true

	var targets: Array[int] = []
	if heretic_target > 0:
		targets.append(heretic_target)
	NightResolver.resolve_many(
		session.players,
		targets,
		healer_target,
		inquisitor_target,
		NightRoundRules.is_first_night(round_number),
	)

static func _choose_role_target(
	session: MatchSession,
	brains: Dictionary,
	role: PlayerState.Role,
	round_number: int,
	decider_peer_id: int,
	healer_self_save_used: bool,
) -> int:
	for player in session.players:
		if not player.alive or player.role != role:
			continue
		if role == PlayerState.Role.HERETIC and player.peer_id != decider_peer_id:
			continue
		var brain: QABotBrain = brains[player.peer_id]
		return brain.choose_runtime_night_target(
			session.players,
			player.peer_id,
			round_number,
			decider_peer_id,
			healer_self_save_used,
		)
	return 0

static func _living_role_peer_id(
	players: Array[PlayerState],
	role: PlayerState.Role,
) -> int:
	for player in players:
		if player.alive and player.role == role:
			return player.peer_id
	return 0
static func _run_vote(session: MatchSession, brains: Dictionary) -> void:
	var votes: Dictionary = {}
	for player in session.players:
		if not player.alive:
			continue
		var brain: QABotBrain = brains[player.peer_id]
		var target := brain.choose_vote_target(session.players, player.peer_id)
		if target != 0:
			votes[player.peer_id] = target
	var sacrificed_peer_id := VoteRules.resolve(session.players, votes, session.rng)
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
