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
	var night_state := {"healer_self_save_used": false}
	var night_history: Array[Dictionary] = []
	var rounds := 0
	while rounds < max_rounds:
		rounds += 1
		var night_trace := _run_night(
			session,
			brains,
			rounds,
			visited_phases,
			night_state,
		)
		night_history.append(night_trace)
		var winner := session.winner()
		if not winner.is_empty():
			_finish(winner, visited_phases)
			return _result(
				session,
				winner,
				rounds,
				visited_phases,
				night_history,
				true,
			)

		_sync_phase(GameManager.MatchPhase.DAY_DISCUSSION, rounds, visited_phases)
		_sync_phase(GameManager.MatchPhase.VOTING, rounds, visited_phases)
		_run_vote(session, brains, rounds, visited_phases)
		winner = session.winner()
		if not winner.is_empty():
			_finish(winner, visited_phases)
			return _result(
				session,
				winner,
				rounds,
				visited_phases,
				night_history,
				true,
			)

	return _result(
		session,
		session.winner(),
		rounds,
		visited_phases,
		night_history,
		false,
	)

static func _run_night(
	session: MatchSession,
	brains: Dictionary,
	round_value: int,
	visited_phases: Array[int],
	night_state: Dictionary,
) -> Dictionary:
	var first_night := NightRoundRules.is_first_night(round_value)
	_sync_phase(GameManager.MatchPhase.NIGHT_START, round_value, visited_phases)
	_sync_phase(GameManager.MatchPhase.HERETIC_ACTION, round_value, visited_phases)

	var decider_peer_id := NightRoundRules.choose_heretic_decider(
		session.players,
		round_value,
	)
	MatchAuthority._broadcast_heretic_decider(decider_peer_id)
	var heretic_target := _choose_role_target(
		session,
		brains,
		PlayerState.Role.HERETIC,
		round_value,
		decider_peer_id,
		bool(night_state.get("healer_self_save_used", false)),
	)

	_sync_phase(GameManager.MatchPhase.HEALER_ACTION, round_value, visited_phases)
	var healer_target := 0
	var inquisitor_target := 0
	if first_night:
		if (
			heretic_target > 0
			and _living_role_peer_id(session.players, PlayerState.Role.HEALER) > 0
		):
			healer_target = heretic_target
			MatchAuthority._receive_private_priest_warning(heretic_target)
	else:
		healer_target = _choose_role_target(
			session,
			brains,
			PlayerState.Role.HEALER,
			round_value,
			decider_peer_id,
			bool(night_state.get("healer_self_save_used", false)),
		)
		var healer_peer_id := _living_role_peer_id(
			session.players,
			PlayerState.Role.HEALER,
		)
		if healer_peer_id > 0 and healer_target == healer_peer_id:
			night_state["healer_self_save_used"] = true

	_sync_phase(GameManager.MatchPhase.INQUISITOR_ACTION, round_value, visited_phases)
	if not first_night:
		inquisitor_target = _choose_role_target(
			session,
			brains,
			PlayerState.Role.INQUISITOR,
			round_value,
			decider_peer_id,
			bool(night_state.get("healer_self_save_used", false)),
		)

	_sync_phase(GameManager.MatchPhase.NIGHT_RESOLUTION, round_value, visited_phases)
	var heretic_targets: Array[int] = []
	if heretic_target > 0:
		heretic_targets.append(heretic_target)
	var result := NightResolver.resolve_many(
		session.players,
		heretic_targets,
		healer_target,
		inquisitor_target,
		first_night,
	)
	var priest_saved := (
		heretic_target > 0
		and healer_target == heretic_target
		and _living_role_peer_id(session.players, PlayerState.Role.HEALER) > 0
	)
	MatchAuthority._sync_night_resolution(result.killed_peer_ids)
	MatchAuthority._sync_public_night_report(
		result.killed_peer_ids,
		priest_saved,
		first_night,
	)
	if result.investigation_target_peer_id > 0:
		MatchAuthority._receive_private_investigation(
			result.investigation_target_peer_id,
			result.investigation_is_heretic,
		)
	_sync_phase(GameManager.MatchPhase.WIN_CHECK, round_value, visited_phases)

	return {
		"round": round_value,
		"first_night": first_night,
		"heretic_decider": decider_peer_id,
		"heretic_target": heretic_target,
		"healer_target": healer_target,
		"inquisitor_target": inquisitor_target,
		"killed_peer_ids": result.killed_peer_ids.duplicate(),
		"kill_suppressed": result.kill_suppressed,
		"priest_saved": priest_saved,
		"healer_self_save_used": bool(
			night_state.get("healer_self_save_used", false)
		),
	}

static func _choose_role_target(
	session: MatchSession,
	brains: Dictionary,
	role: PlayerState.Role,
	round_value: int,
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
			round_value,
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

	var top_targets := VoteRules.top_targets(session.players, votes)
	var tied := top_targets.size() > 1
	var sacrificed_peer_id := 0
	if top_targets.size() == 1:
		sacrificed_peer_id = top_targets[0]
	elif tied:
		sacrificed_peer_id = top_targets[session.rng.randi_range(0, top_targets.size() - 1)]

	var was_heretic := false
	_sync_phase(GameManager.MatchPhase.SACRIFICE, round_value, visited_phases)
	if sacrificed_peer_id > 0:
		var sacrificed := session.get_player(sacrificed_peer_id)
		was_heretic = sacrificed != null and sacrificed.role == PlayerState.Role.HERETIC
		session.sacrifice(sacrificed_peer_id)
	MatchAuthority._sync_sacrifice(sacrificed_peer_id, tied, was_heretic)
	_sync_phase(GameManager.MatchPhase.WIN_CHECK, round_value, visited_phases)

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
	night_history: Array[Dictionary],
	completed: bool,
) -> Dictionary:
	return {
		"completed": completed,
		"winner": str(winner),
		"rounds": rounds,
		"players": session.players.size(),
		"living": session.living_players().size(),
		"visited_phases": visited_phases.duplicate(),
		"night_history": night_history.duplicate(true),
	}
