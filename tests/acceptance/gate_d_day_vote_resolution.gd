extends "res://tests/acceptance/gate_d_full_night_actions_runtime.gd"

var _voting_started := false
var _vote_sent := false
var _planned_vote_target := 0
var _living_before_vote := 0
var _vote_resolution_seen := false
var _vote_resolution_requested := false
var _sacrificed_peer_id := 0
var _vote_tied := false
var _vote_ack_sent := false
var _server_vote_ready := false
var _d6_completed := false
var _vote_validated_clients: Dictionary = {}

func _ready() -> void:
	super()
	MatchAuthority.vote_accepted.connect(_on_d6_vote_accepted)
	MatchAuthority.vote_resolution_received.connect(_on_vote_resolution_received)
	MatchAuthority.vote_state_synced.connect(_on_vote_state_synced)
	MatchAuthority.phase_synced.connect(_on_d6_phase_synced)

func _handle_day_discussion() -> void:
	var validation_error := _local_day_validation_error()
	if not validation_error.is_empty():
		_fail(validation_error)
		return
	if _role == "server" and not _voting_started:
		call_deferred("_begin_voting")

func _begin_voting() -> void:
	if _voting_started or GameManager.phase != GameManager.MatchPhase.DAY_DISCUSSION:
		return
	_voting_started = true
	_living_before_vote = _living_public_count()
	if _living_before_vote < 2:
		_fail("not enough living players to validate voting")
		return
	MatchAuthority.request_begin_voting()

func _on_d6_phase_synced(phase_value: int) -> void:
	if phase_value == int(GameManager.MatchPhase.VOTING):
		_planned_vote_target = _first_alive_peer()
		if _planned_vote_target <= 0:
			_fail("could not choose public vote target")
	elif phase_value == int(GameManager.MatchPhase.SACRIFICE):
		if _role == "server":
			_server_vote_ready = true
			_try_complete_d6_server()
		else:
			_try_send_vote_ack()

func _on_vote_state_synced(_votes: Dictionary, current_voter_peer_id: int) -> void:
	if GameManager.phase != GameManager.MatchPhase.VOTING:
		return
	if current_voter_peer_id != multiplayer.get_unique_id():
		return
	call_deferred("_submit_day_vote")

func _submit_day_vote() -> void:
	if _vote_sent or GameManager.phase != GameManager.MatchPhase.VOTING:
		return
	var local_peer_id := multiplayer.get_unique_id()
	if MatchAuthority.current_voter_peer_id != local_peer_id:
		return
	if not MatchAuthority.is_peer_publicly_alive(local_peer_id):
		return
	var vote_target := _planned_vote_target
	if local_peer_id == vote_target:
		vote_target = _second_alive_peer(vote_target)
	if vote_target <= 0:
		_fail("living voter could not choose a valid target")
		return
	_vote_sent = true
	MatchAuthority.submit_local_vote(vote_target)

func _on_d6_vote_accepted(_voter_peer_id: int, _target_peer_id: int) -> void:
	if _role != "server" or _vote_resolution_requested:
		return
	if GameManager.phase != GameManager.MatchPhase.VOTING or _living_before_vote <= 0:
		return
	if MatchAuthority._valid_vote_count() < _living_before_vote:
		return
	_vote_resolution_requested = true
	call_deferred("_resolve_d6_vote")

func _resolve_d6_vote() -> void:
	if GameManager.phase != GameManager.MatchPhase.VOTING:
		return
	MatchAuthority._clear_phase_timeout()
	MatchAuthority._handle_phase_timeout(GameManager.MatchPhase.VOTING)

func _first_alive_peer() -> int:
	var peer_ids := _sorted_peer_ids()
	for peer_id in peer_ids:
		if MatchAuthority.is_peer_publicly_alive(peer_id):
			return peer_id
	return 0

func _second_alive_peer(excluded_peer_id: int) -> int:
	var peer_ids := _sorted_peer_ids()
	for peer_id in peer_ids:
		if peer_id != excluded_peer_id and MatchAuthority.is_peer_publicly_alive(peer_id):
			return peer_id
	return 0

func _sorted_peer_ids() -> Array[int]:
	var peer_ids: Array[int] = []
	for raw_peer_id in NetworkManager.peers.keys():
		peer_ids.append(int(raw_peer_id))
	peer_ids.sort()
	return peer_ids

func _living_public_count() -> int:
	var count := 0
	for peer_id in _sorted_peer_ids():
		if MatchAuthority.is_peer_publicly_alive(peer_id):
			count += 1
	return count

func _on_vote_resolution_received(sacrificed_peer_id: int, tied: bool) -> void:
	_vote_resolution_seen = true
	_sacrificed_peer_id = sacrificed_peer_id
	_vote_tied = tied
	if tied:
		_fail("deterministic vote unexpectedly tied")
		return
	if sacrificed_peer_id != _planned_vote_target:
		_fail("sacrificed peer did not match deterministic vote target")
		return
	if MatchAuthority.is_peer_publicly_alive(sacrificed_peer_id):
		_fail("sacrificed peer remained publicly alive")
		return
	if _role == "server":
		_try_complete_d6_server()
	else:
		_try_send_vote_ack()

func _try_send_vote_ack() -> void:
	if _vote_ack_sent or not _vote_resolution_seen or not _saw_vote_sequence():
		return
	_vote_ack_sent = true
	_ack_vote_state.rpc_id(
		1,
		_sacrificed_peer_id,
		_vote_tied,
		_dead_peer_count(),
		_saw_vote_sequence(),
	)

func _saw_vote_sequence() -> bool:
	for required_phase in [
		GameManager.MatchPhase.DAY_DISCUSSION,
		GameManager.MatchPhase.VOTING,
		GameManager.MatchPhase.SACRIFICE,
	]:
		if int(required_phase) not in _visited_phases:
			return false
	return true

@rpc("any_peer", "call_remote", "reliable")
func _ack_vote_state(
	sacrificed_peer_id: int,
	tied: bool,
	dead_peer_count: int,
	saw_vote_sequence: bool,
) -> void:
	if _role != "server":
		return
	var sender_id := multiplayer.get_remote_sender_id()
	var validation_error := _client_vote_ack_validation_error(
		sacrificed_peer_id,
		tied,
		dead_peer_count,
		saw_vote_sequence,
	)
	if not validation_error.is_empty():
		_fail(validation_error)
		return
	if _vote_validated_clients.has(sender_id):
		_fail("server received duplicate vote acknowledgement")
		return
	_vote_validated_clients[sender_id] = true
	_try_complete_d6_server()

func _client_vote_ack_validation_error(
	sacrificed_peer_id: int,
	tied: bool,
	dead_peer_count: int,
	saw_vote_sequence: bool,
) -> String:
	var error := ""
	if tied:
		error = "client reported tied deterministic vote"
	elif sacrificed_peer_id != _planned_vote_target:
		error = "client sacrificed peer diverged from server target"
	elif dead_peer_count != _dead_peer_count():
		error = "client public death count diverged after sacrifice"
	elif not saw_vote_sequence:
		error = "client missed part of day vote sequence"
	return error

func _server_vote_validation_error() -> String:
	var votes: Dictionary = MatchAuthority.get("_votes")
	var error := ""
	if not _vote_resolution_seen or not _server_vote_ready:
		error = "server did not observe complete vote resolution"
	elif _vote_tied or _sacrificed_peer_id != _planned_vote_target:
		error = "server deterministic vote resolved incorrectly"
	elif votes.size() != _living_before_vote:
		error = "server did not receive one vote from every living player"
	elif MatchAuthority.is_peer_publicly_alive(_sacrificed_peer_id):
		error = "server sacrifice did not update public alive state"
	elif not _public_alive_matches_session():
		error = "server public alive state diverged after sacrifice"
	elif not _saw_vote_sequence():
		error = "server missed part of day vote sequence"
	return error

func _try_complete_d6_server() -> void:
	if _d6_completed or not _server_vote_ready or not _vote_resolution_seen:
		return
	var validation_error := _server_vote_validation_error()
	if not validation_error.is_empty():
		_fail(validation_error)
		return
	if _vote_validated_clients.size() != EXPECTED_CLIENTS:
		return
	_d6_completed = true
	_confirm_day_vote.rpc()
	print("GREEN: Gate D6 server - exact-8 day vote and sacrifice converged")
	_server_quit_delay = 0.25

@rpc("authority", "call_remote", "reliable")
func _confirm_day_vote() -> void:
	if _role != "client":
		return
	print("GREEN: Gate D6 client %d - day vote and sacrifice matched" % _client_index)
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("RED: Gate D6 %s%s - %s" % [_role, _client_suffix(), message])
	get_tree().quit(1)
