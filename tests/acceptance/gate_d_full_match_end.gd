extends "res://tests/acceptance/gate_d_role_reveal_ack.gd"

const D7_TIMEOUT_SECONDS := 25.0
const EXPECTED_FINAL_ROUND := 2

var _plan_round := 0
var _plan_heretic_target := 0
var _plan_healer_target := 0
var _plan_inquisitor_target := 0
var _plan_vote_target := 0
var _submitted_action_rounds: Dictionary = {}
var _accepted_action_rounds: Dictionary = {}
var _pending_action_round := 0
var _night_resolution_rounds: Dictionary = {}
var _submitted_vote_rounds: Dictionary = {}
var _vote_resolution_rounds: Dictionary = {}
var _win_check_rounds: Dictionary = {}
var _server_accepted_actions: Dictionary = {}
var _server_accepted_votes: Dictionary = {}
var _server_expected_voters: Dictionary = {}
var _server_vote_targets: Dictionary = {}
var _final_ack_sent := false
var _server_match_end_ready := false
var _d7_completed := false
var _final_validated_clients: Dictionary = {}

func _ready() -> void:
	super()
	MatchAuthority.night_action_result_received.connect(_on_d7_night_action_result)
	MatchAuthority.night_action_accepted.connect(_on_d7_night_action_accepted)
	MatchAuthority.night_resolution_received.connect(_on_d7_night_resolution)
	MatchAuthority.vote_accepted.connect(_on_d7_vote_accepted)
	MatchAuthority.vote_resolution_received.connect(_on_d7_vote_resolution)
	MatchAuthority.match_end_received.connect(_on_d7_match_end)

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= D7_TIMEOUT_SECONDS:
		_fail("%s timed out" % _role)
		return
	if _role == "server" and not _match_started:
		_process_server_roster(delta)
	if _server_quit_delay >= 0.0:
		_server_quit_delay -= delta
		if _server_quit_delay <= 0.0:
			get_tree().quit(0)

func _on_phase_synced(phase_value: int) -> void:
	var round_value := GameManager.round_number
	if phase_value == int(GameManager.MatchPhase.HERETIC_ACTION):
		if _role == "server" and _plan_round != round_value:
			_broadcast_round_plan()
		call_deferred("_try_submit_planned_action")
	elif NightPhaseRules.is_action_phase(GameManager.phase):
		call_deferred("_try_submit_planned_action")
	elif phase_value == int(GameManager.MatchPhase.DAY_DISCUSSION):
		if _role == "server":
			call_deferred("_begin_planned_voting")
	elif phase_value == int(GameManager.MatchPhase.VOTING):
		if _role == "server":
			_server_expected_voters[round_value] = _living_session_count()
		call_deferred("_try_submit_planned_vote")
	elif phase_value == int(GameManager.MatchPhase.WIN_CHECK):
		_win_check_rounds[round_value] = true
		if _role == "server":
			_validate_win_check(round_value)

func _broadcast_round_plan() -> void:
	var validation_error := _server_plan_validation_error()
	if not validation_error.is_empty():
		_fail(validation_error)
		return
	var heretics := _alive_role_peers(PlayerState.Role.HERETIC)
	var faithful_side := _alive_non_heretic_peers()
	var round_value := GameManager.round_number
	var heretic_target := faithful_side[0]
	var vote_target := heretics[0]
	_server_vote_targets[round_value] = vote_target
	_sync_round_plan.rpc(
		round_value,
		heretic_target,
		heretic_target,
		vote_target,
		vote_target,
	)

func _server_plan_validation_error() -> String:
	var error := ""
	var round_value := GameManager.round_number
	var heretics := _alive_role_peers(PlayerState.Role.HERETIC)
	var faithful_side := _alive_non_heretic_peers()
	if round_value < 1 or round_value > EXPECTED_FINAL_ROUND:
		error = "unexpected round while building deterministic plan"
	elif heretics.is_empty():
		error = "no living heretic available for deterministic plan"
	elif faithful_side.is_empty():
		error = "no faithful-side target available for deterministic plan"
	elif round_value == 1:
		error = _server_runtime_validation_error()
	return error

@rpc("authority", "call_local", "reliable")
func _sync_round_plan(
	round_value: int,
	heretic_target: int,
	healer_target: int,
	inquisitor_target: int,
	vote_target: int,
) -> void:
	_plan_round = round_value
	_plan_heretic_target = heretic_target
	_plan_healer_target = healer_target
	_plan_inquisitor_target = inquisitor_target
	_plan_vote_target = vote_target
	call_deferred("_try_submit_planned_action")

func _try_submit_planned_action() -> void:
	if not NightPhaseRules.is_action_phase(GameManager.phase):
		return
	var round_value := GameManager.round_number
	if _plan_round != round_value or _submitted_action_rounds.has(round_value):
		return
	var local_peer_id := multiplayer.get_unique_id()
	if not MatchAuthority.is_peer_publicly_alive(local_peer_id):
		return
	var required_role := NightPhaseRules.role_for_phase(GameManager.phase)
	if required_role != MatchAuthority.local_role:
		return
	var target_peer_id := _target_for_role(required_role)
	if target_peer_id <= 0:
		_fail("active role had no deterministic target")
		return
	_submitted_action_rounds[round_value] = true
	_pending_action_round = round_value
	MatchAuthority.submit_local_night_target(target_peer_id)

func _target_for_role(role_value: PlayerState.Role) -> int:
	match role_value:
		PlayerState.Role.HERETIC:
			return _plan_heretic_target
		PlayerState.Role.HEALER:
			return _plan_healer_target
		PlayerState.Role.INQUISITOR:
			return _plan_inquisitor_target
		_:
			return 0

func _on_d7_night_action_result(accepted: bool, _target_peer_id: int) -> void:
	if _pending_action_round <= 0:
		return
	if not accepted:
		_fail("planned night action was rejected")
		return
	_accepted_action_rounds[_pending_action_round] = true
	_pending_action_round = 0

func _on_d7_night_action_accepted(actor_peer_id: int, target_peer_id: int) -> void:
	if _role != "server":
		return
	var round_value := GameManager.round_number
	var accepted: Dictionary = _server_accepted_actions.get(round_value, {})
	accepted[actor_peer_id] = target_peer_id
	_server_accepted_actions[round_value] = accepted

func _on_d7_night_resolution(killed_peer_ids: Array[int]) -> void:
	var round_value := GameManager.round_number
	if not killed_peer_ids.is_empty():
		_fail("protected deterministic night unexpectedly killed a player")
		return
	_night_resolution_rounds[round_value] = true
	if _role == "server":
		var error := _server_night_validation_error(round_value)
		if not error.is_empty():
			_fail(error)

func _server_night_validation_error(round_value: int) -> String:
	var accepted: Dictionary = _server_accepted_actions.get(round_value, {})
	var expected_count := _expected_active_role_count()
	var error := ""
	if accepted.size() != expected_count:
		error = "server did not accept every living night actor"
	else:
		for raw_actor_id in accepted.keys():
			var actor_id := int(raw_actor_id)
			var role_value := MatchAuthority.server_role_for_peer(actor_id)
			var expected_target := _target_for_role(role_value)
			if int(accepted[raw_actor_id]) != expected_target:
				error = "server accepted a night target outside the round plan"
				break
	return error

func _begin_planned_voting() -> void:
	if GameManager.phase != GameManager.MatchPhase.DAY_DISCUSSION:
		return
	if _plan_round != GameManager.round_number or _plan_vote_target <= 0:
		_fail("day discussion reached without a current vote plan")
		return
	MatchAuthority.request_begin_voting()

func _try_submit_planned_vote() -> void:
	if GameManager.phase != GameManager.MatchPhase.VOTING:
		return
	var round_value := GameManager.round_number
	if _plan_round != round_value or _submitted_vote_rounds.has(round_value):
		return
	var local_peer_id := multiplayer.get_unique_id()
	if not MatchAuthority.is_peer_publicly_alive(local_peer_id):
		return
	var target_peer_id := _plan_vote_target
	if local_peer_id == target_peer_id:
		target_peer_id = _first_alive_peer_other_than(local_peer_id)
	if target_peer_id <= 0:
		_fail("living voter had no valid deterministic target")
		return
	_submitted_vote_rounds[round_value] = true
	MatchAuthority.submit_local_vote(target_peer_id)

func _on_d7_vote_accepted(voter_peer_id: int, target_peer_id: int) -> void:
	if _role != "server":
		return
	var round_value := GameManager.round_number
	var accepted: Dictionary = _server_accepted_votes.get(round_value, {})
	accepted[voter_peer_id] = target_peer_id
	_server_accepted_votes[round_value] = accepted

func _on_d7_vote_resolution(sacrificed_peer_id: int, tied: bool) -> void:
	var round_value := GameManager.round_number
	if tied or sacrificed_peer_id != _plan_vote_target:
		_fail("deterministic heretic vote resolved incorrectly")
		return
	if MatchAuthority.is_peer_publicly_alive(sacrificed_peer_id):
		_fail("voted heretic remained publicly alive")
		return
	_vote_resolution_rounds[round_value] = true
	if _role == "server":
		var error := _server_vote_round_validation_error(round_value, sacrificed_peer_id)
		if not error.is_empty():
			_fail(error)

func _server_vote_round_validation_error(round_value: int, sacrificed_peer_id: int) -> String:
	var accepted: Dictionary = _server_accepted_votes.get(round_value, {})
	var expected_voters := int(_server_expected_voters.get(round_value, 0))
	var error := ""
	if MatchAuthority.server_role_for_peer(sacrificed_peer_id) != PlayerState.Role.HERETIC:
		error = "deterministic vote did not sacrifice a heretic"
	elif accepted.size() != expected_voters:
		error = "server did not accept one vote from every living player"
	elif not _public_alive_matches_session():
		error = "public alive state diverged after deterministic sacrifice"
	return error

func _validate_win_check(round_value: int) -> void:
	var session: MatchSession = MatchAuthority.get("_session")
	if session == null:
		_fail("server lost authoritative session before win check")
		return
	var winner := session.winner()
	if round_value == 1 and not winner.is_empty():
		_fail("match ended before second deterministic round")
	elif round_value == EXPECTED_FINAL_ROUND and winner != &"faithful":
		_fail("second-round win check did not produce faithful winner")

func _on_d7_match_end(winner: StringName) -> void:
	var error := _local_match_end_validation_error(winner)
	if not error.is_empty():
		_fail(error)
		return
	if _role == "server":
		_server_match_end_ready = true
		var server_error := _server_match_end_validation_error()
		if not server_error.is_empty():
			_fail(server_error)
			return
		_try_complete_d7_server()
	elif not _final_ack_sent:
		_final_ack_sent = true
		_ack_final_match.rpc_id(
			1,
			int(MatchAuthority.local_role),
			str(winner),
			GameManager.round_number,
			_dead_peer_count(),
			_night_resolution_rounds.size(),
			_vote_resolution_rounds.size(),
		)

func _local_match_end_validation_error(winner: StringName) -> String:
	var error := ""
	if winner != &"faithful" or MatchAuthority.public_winner != &"faithful":
		error = "final winner did not converge to faithful"
	elif GameManager.round_number != EXPECTED_FINAL_ROUND:
		error = "match ended on unexpected round"
	elif NetworkManager.peers.size() != EXPECTED_PLAYERS:
		error = "roster changed before match end"
	elif _dead_peer_count() != 2:
		error = "full match did not end with exactly two public deaths"
	elif _night_resolution_rounds.size() != EXPECTED_FINAL_ROUND:
		error = "client missed a night resolution"
	elif _vote_resolution_rounds.size() != EXPECTED_FINAL_ROUND:
		error = "client missed a vote resolution"
	elif _win_check_rounds.size() != EXPECTED_FINAL_ROUND:
		error = "client missed a win check"
	return error

func _server_match_end_validation_error() -> String:
	var session: MatchSession = MatchAuthority.get("_session")
	var error := ""
	if session == null or session.winner() != &"faithful":
		error = "authoritative session winner was not faithful"
	elif not _public_alive_matches_session():
		error = "final public alive state diverged from session"
	elif _alive_role_peers(PlayerState.Role.HERETIC).size() != 0:
		error = "a heretic remained alive at faithful match end"
	elif _server_vote_targets.size() != EXPECTED_FINAL_ROUND:
		error = "server did not create exactly two deterministic round plans"
	return error

@rpc("any_peer", "call_remote", "reliable")
func _ack_final_match(
	role_value: int,
	winner_value: String,
	round_value: int,
	dead_peer_count: int,
	night_resolution_count: int,
	vote_resolution_count: int,
) -> void:
	if _role != "server":
		return
	var sender_id := multiplayer.get_remote_sender_id()
	var error := _final_client_ack_error(
		sender_id,
		role_value,
		winner_value,
		round_value,
		dead_peer_count,
		night_resolution_count,
		vote_resolution_count,
	)
	if not error.is_empty():
		_fail(error)
		return
	if _final_validated_clients.has(sender_id):
		_fail("server received duplicate final match acknowledgement")
		return
	_final_validated_clients[sender_id] = true
	_try_complete_d7_server()

func _final_client_ack_error(
	sender_id: int,
	role_value: int,
	winner_value: String,
	round_value: int,
	dead_peer_count: int,
	night_resolution_count: int,
	vote_resolution_count: int,
) -> String:
	var error := ""
	if role_value != int(MatchAuthority.server_role_for_peer(sender_id)):
		error = "client final role diverged from authoritative role"
	elif winner_value != "faithful" or round_value != EXPECTED_FINAL_ROUND:
		error = "client final winner or round diverged"
	elif dead_peer_count != 2:
		error = "client final public death count diverged"
	elif night_resolution_count != EXPECTED_FINAL_ROUND:
		error = "client final night count diverged"
	elif vote_resolution_count != EXPECTED_FINAL_ROUND:
		error = "client final vote count diverged"
	return error

func _try_complete_d7_server() -> void:
	if _d7_completed or not _server_match_end_ready:
		return
	if _final_validated_clients.size() != EXPECTED_CLIENTS:
		return
	_d7_completed = true
	_confirm_full_match.rpc()
	print("GREEN: Gate D7 server - exact-8 two-round match reached faithful MATCH_END")
	_server_quit_delay = 0.25

func _alive_role_peers(role_value: PlayerState.Role) -> Array[int]:
	var result: Array[int] = []
	var session: MatchSession = MatchAuthority.get("_session")
	if session == null:
		return result
	for player in session.players:
		if player.alive and player.role == role_value:
			result.append(player.peer_id)
	result.sort()
	return result

func _alive_non_heretic_peers() -> Array[int]:
	var result: Array[int] = []
	var session: MatchSession = MatchAuthority.get("_session")
	if session == null:
		return result
	for player in session.players:
		if player.alive and player.role != PlayerState.Role.HERETIC:
			result.append(player.peer_id)
	result.sort()
	return result

func _expected_active_role_count() -> int:
	return (
		_alive_role_peers(PlayerState.Role.HERETIC).size()
		+ _alive_role_peers(PlayerState.Role.HEALER).size()
		+ _alive_role_peers(PlayerState.Role.INQUISITOR).size()
	)

func _living_session_count() -> int:
	var session: MatchSession = MatchAuthority.get("_session")
	return 0 if session == null else session.living_players().size()

func _dead_peer_count() -> int:
	var count := 0
	for raw_peer_id in NetworkManager.peers.keys():
		if not MatchAuthority.is_peer_publicly_alive(int(raw_peer_id)):
			count += 1
	return count

func _public_alive_matches_session() -> bool:
	var session: MatchSession = MatchAuthority.get("_session")
	if session == null:
		return false
	for player in session.players:
		if MatchAuthority.is_peer_publicly_alive(player.peer_id) != player.alive:
			return false
	return true

func _first_alive_peer_other_than(excluded_peer_id: int) -> int:
	var peer_ids: Array[int] = []
	for raw_peer_id in NetworkManager.peers.keys():
		peer_ids.append(int(raw_peer_id))
	peer_ids.sort()
	for peer_id in peer_ids:
		if peer_id != excluded_peer_id and MatchAuthority.is_peer_publicly_alive(peer_id):
			return peer_id
	return 0

@rpc("authority", "call_remote", "reliable")
func _confirm_full_match() -> void:
	if _role != "client":
		return
	print("GREEN: Gate D7 client %d - exact-8 full match state matched" % _client_index)
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("RED: Gate D7 %s%s - %s" % [_role, _client_suffix(), message])
	get_tree().quit(1)
