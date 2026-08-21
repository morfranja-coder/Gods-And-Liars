class_name QAAdversarialSimulator
extends RefCounted

enum Fault {
	NONE,
	AFK_NIGHT,
	INVALID_VOTE,
	DUPLICATE_VOTE,
	DISCONNECT_AFTER_NIGHT,
}

const BOT_COUNT := QuickMatchRules.TARGET_PLAYERS
const DEFAULT_MAX_ROUNDS := 40

static func run(
	seed_value: int,
	fault: Fault = Fault.NONE,
	fault_peer_id: int = 1,
	max_rounds: int = DEFAULT_MAX_ROUNDS,
) -> Dictionary:
	var session := _build_session(seed_value)
	if session == null:
		return {"completed": false, "blocked": false, "reason": "prepare_failed", "rounds": 0}
	var night_fault_peer_id := _resolve_night_fault_peer_id(session, fault, fault_peer_id)
	var brains := _build_brains(session)
	var rounds := 0
	var fault_consumed := false
	while rounds < max_rounds:
		var winner := session.winner()
		if not winner.is_empty():
			return _result(session, winner, rounds, true, false, fault_consumed)
		rounds += 1
		var night_result := _run_night(
			session,
			brains,
			fault,
			night_fault_peer_id,
			fault_consumed,
		)
		fault_consumed = fault_consumed or bool(night_result.get("fault_consumed", false))
		if bool(night_result.get("blocked", false)):
			return _result(session, session.winner(), rounds, false, true, fault_consumed)
		winner = session.winner()
		if not winner.is_empty():
			return _result(session, winner, rounds, true, false, fault_consumed)
		if fault == Fault.DISCONNECT_AFTER_NIGHT and not fault_consumed:
			var disconnect_peer_id := _resolve_living_fault_peer_id(session, fault_peer_id)
			var disconnected := session.get_player(disconnect_peer_id)
			if disconnected != null and disconnected.alive:
				disconnected.alive = false
				fault_consumed = true
				winner = session.winner()
				if not winner.is_empty():
					return _result(session, winner, rounds, true, false, fault_consumed)
		var vote_fault_peer_id := _resolve_living_fault_peer_id(session, fault_peer_id)
		var vote_result := _run_vote(
			session,
			brains,
			fault,
			vote_fault_peer_id,
			fault_consumed,
		)
		fault_consumed = fault_consumed or bool(vote_result.get("fault_consumed", false))
		if bool(vote_result.get("blocked", false)):
			return _result(session, session.winner(), rounds, false, true, fault_consumed)
		winner = session.winner()
		if not winner.is_empty():
			return _result(session, winner, rounds, true, false, fault_consumed)
	return _result(session, session.winner(), rounds, false, true, fault_consumed)

static func _build_session(seed_value: int) -> MatchSession:
	var session := MatchSession.new(seed_value)
	for index in range(BOT_COUNT):
		var peer_id := index + 1
		if not session.add_player(peer_id, 910000 + peer_id, "QA Adv Bot %d" % peer_id):
			return null
		var player := session.get_player(peer_id)
		player.ready = true
	return session if session.prepare_match() else null

static func _resolve_night_fault_peer_id(
	session: MatchSession,
	fault: Fault,
	requested_peer_id: int,
) -> int:
	if fault != Fault.AFK_NIGHT:
		return requested_peer_id
	if requested_peer_id > 0:
		var requested := session.get_player(requested_peer_id)
		if requested != null and requested.alive and requested.role in [
			PlayerState.Role.HERETIC,
			PlayerState.Role.HEALER,
			PlayerState.Role.INQUISITOR,
		]:
			return requested_peer_id
	for player in session.players:
		if player.alive and player.role in [
			PlayerState.Role.HERETIC,
			PlayerState.Role.HEALER,
			PlayerState.Role.INQUISITOR,
		]:
			return player.peer_id
	return 0

static func _resolve_living_fault_peer_id(session: MatchSession, requested_peer_id: int) -> int:
	if requested_peer_id > 0:
		var requested := session.get_player(requested_peer_id)
		if requested != null and requested.alive:
			return requested_peer_id
	for player in session.players:
		if player.alive:
			return player.peer_id
	return 0

static func _build_brains(session: MatchSession) -> Dictionary:
	var brains: Dictionary = {}
	for player in session.players:
		brains[player.peer_id] = QABotBrain.new(QABotBrain.Profile.BALANCED)
	return brains

static func _run_night(
	session: MatchSession,
	brains: Dictionary,
	fault: Fault,
	fault_peer_id: int,
	fault_consumed: bool,
) -> Dictionary:
	var heretic_targets: Array[int] = []
	var healer_target := 0
	var inquisitor_target := 0
	for player in session.players:
		if not player.alive:
			continue
		if fault == Fault.AFK_NIGHT and not fault_consumed and player.peer_id == fault_peer_id:
			if player.role in [PlayerState.Role.HERETIC, PlayerState.Role.HEALER, PlayerState.Role.INQUISITOR]:
				return {"blocked": true, "fault_consumed": true}
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
	NightResolver.resolve_many(session.players, heretic_targets, healer_target, inquisitor_target)
	return {"blocked": false, "fault_consumed": false}

static func _run_vote(
	session: MatchSession,
	brains: Dictionary,
	fault: Fault,
	fault_peer_id: int,
	fault_consumed: bool,
) -> Dictionary:
	var votes: Dictionary = {}
	var consumed := false
	for player in session.players:
		if not player.alive:
			continue
		var brain: QABotBrain = brains[player.peer_id]
		var target := brain.choose_vote_target(session.players, player.peer_id)
		if target == 0:
			continue
		if not fault_consumed and player.peer_id == fault_peer_id:
			if fault == Fault.INVALID_VOTE:
				if VoteRules.can_vote(session.players, player.peer_id, player.peer_id):
					return {"blocked": true, "fault_consumed": true}
				consumed = true
				continue
			elif fault == Fault.DUPLICATE_VOTE:
				votes[player.peer_id] = target
				var replacement := _next_vote_target(session.players, player.peer_id, target)
				if replacement != 0:
					votes[player.peer_id] = replacement
				consumed = true
				continue
		votes[player.peer_id] = target
	var expected_votes := VoteRules.living_count(session.players)
	if votes.size() < expected_votes:
		return {"blocked": true, "fault_consumed": consumed}
	var sacrificed_peer_id := VoteRules.resolve(session.players, votes)
	if sacrificed_peer_id > 0:
		session.sacrifice(sacrificed_peer_id)
	return {"blocked": false, "fault_consumed": consumed}

static func _next_vote_target(players: Array[PlayerState], voter_peer_id: int, current_target: int) -> int:
	var candidates: Array[int] = []
	for target in players:
		if target.peer_id != current_target and VoteRules.can_vote(players, voter_peer_id, target.peer_id):
			candidates.append(target.peer_id)
	candidates.sort()
	return 0 if candidates.is_empty() else candidates[0]

static func _result(
	session: MatchSession,
	winner_name: StringName,
	rounds: int,
	completed: bool,
	blocked: bool,
	fault_consumed: bool,
) -> Dictionary:
	return {
		"completed": completed,
		"blocked": blocked,
		"winner": str(winner_name),
		"rounds": rounds,
		"living": session.living_players().size(),
		"players": session.players.size(),
		"fault_consumed": fault_consumed,
	}
