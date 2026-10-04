extends "res://tests/acceptance/gate_d_full_night_actions_runtime.gd"

const D11_TIMEOUT_SECONDS := 30.0

var _scenario := ""
var _vote_sent := false
var _resolution_seen := false
var _sacrifice_phase_seen := false
var _sacrificed_peer_id := 0
var _vote_tied := false
var _server_resolution_ready := false
var _final_ack_sent := false
var _d11_completed := false
var _accepted_votes: Dictionary = {}
var _tie_validated_clients: Dictionary = {}
var _expected_tied_targets: Array[int] = []

func _ready() -> void:
	_parse_tie_scenario()
	super()
	if _scenario not in ["four_way", "three_three"]:
		_fail("missing or invalid D11 tie scenario")
		return
	MatchAuthority.vote_accepted.connect(_on_d11_vote_accepted)
	MatchAuthority.vote_resolution_received.connect(_on_d11_vote_resolution)
	MatchAuthority.vote_state_synced.connect(_on_d11_vote_state_synced)
	MatchAuthority.phase_synced.connect(_on_d11_phase_synced)

func _process(delta: float) -> void:
	if _server_quit_delay >= 0.0:
		_server_quit_delay -= delta
		if _server_quit_delay <= 0.0:
			get_tree().quit(0)
			return

	_elapsed += delta
	if _elapsed >= D11_TIMEOUT_SECONDS:
		_fail(
			"%s timed out (scenario=%s phase=%d accepted=%d acks=%d)"
			% [
				_role,
				_scenario,
				int(GameManager.phase),
				_accepted_votes.size(),
				_tie_validated_clients.size(),
			]
		)
		return

	if _role == "server" and not _match_started:
		_process_server_roster(delta)
	if _role == "server":
		_process_server_phase_fast_forward(delta)
	if _match_started and NightPhaseRules.is_action_phase(GameManager.phase):
		_try_submit_night_action()

func _parse_tie_scenario() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 2:
		_scenario = str(args[2]).strip_edges().to_lower()

func _handle_day_discussion() -> void:
	var validation_error := _local_day_validation_error()
	if not validation_error.is_empty():
		_fail(validation_error)
		return
	if _role == "server":
		call_deferred("_begin_tie_voting")

func _begin_tie_voting() -> void:
	if GameManager.phase != GameManager.MatchPhase.DAY_DISCUSSION:
		return
	var peers := _sorted_alive_peers()
	if peers.size() != EXPECTED_PLAYERS:
		_fail("D11 requires all eight players alive before voting")
		return
	_expected_tied_targets = _expected_targets_for_scenario(peers)
	if _expected_tied_targets.is_empty():
		_fail("D11 could not build expected tie targets")
		return
	MatchAuthority.request_begin_voting()

func _on_d11_vote_state_synced(_votes: Dictionary, _voter_peer_id: int) -> void:
	if GameManager.phase == GameManager.MatchPhase.VOTING:
		call_deferred("_submit_planned_tie_vote")

func _submit_planned_tie_vote() -> void:
	if _vote_sent or GameManager.phase != GameManager.MatchPhase.VOTING:
		return
	var peers := _sorted_alive_peers()
	if peers.size() != EXPECTED_PLAYERS:
		_fail("D11 local roster diverged before vote")
		return
	var local_peer_id := multiplayer.get_unique_id()
	var target_peer_id := _planned_target_for(local_peer_id, peers)
	if target_peer_id <= 0 or target_peer_id == local_peer_id:
		_fail("D11 produced invalid local tie vote")
		return
	_vote_sent = true
	MatchAuthority.submit_local_vote(target_peer_id)

func _planned_target_for(voter_peer_id: int, peers: Array[int]) -> int:
	var voter_index := peers.find(voter_peer_id)
	if voter_index < 0:
		return 0
	var target_indices: Array[int] = []
	if _scenario == "four_way":
		target_indices = [1, 0, 0, 1, 2, 2, 3, 3]
	elif _scenario == "three_three":
		target_indices = [1, 0, 0, 0, 1, 1, 2, 3]
	if voter_index >= target_indices.size():
		return 0
	return peers[target_indices[voter_index]]

func _expected_targets_for_scenario(peers: Array[int]) -> Array[int]:
	var result: Array[int] = []
	var count := 4 if _scenario == "four_way" else 2
	for index in range(count):
		result.append(peers[index])
	return result

func _on_d11_vote_accepted(voter_peer_id: int, target_peer_id: int) -> void:
	if _role != "server":
		return
	_accepted_votes[voter_peer_id] = target_peer_id

func _on_d11_vote_resolution(sacrificed_peer_id: int, tied: bool) -> void:
	_resolution_seen = true
	_sacrificed_peer_id = sacrificed_peer_id
	_vote_tied = tied
	var error := _local_resolution_error()
	if not error.is_empty():
		_fail(error)
		return
	if _role == "server":
		_server_resolution_ready = true
		_try_complete_d11()
	else:
		_try_send_d11_ack()

func _on_d11_phase_synced(phase_value: int) -> void:
	if phase_value != int(GameManager.MatchPhase.SACRIFICE):
		return
	_sacrifice_phase_seen = true
	if _role == "server":
		_try_complete_d11()
	else:
		_try_send_d11_ack()

func _local_resolution_error() -> String:
	var error := ""
	if not _vote_tied:
		error = "D11 tie scenario resolved without tied=true"
	elif _sacrificed_peer_id <= 0:
		error = "D11 tie scenario resolved without a sacrifice"
	elif _sacrificed_peer_id not in _expected_tied_targets:
		error = "D11 sacrificed peer was outside the tied top set"
	elif MatchAuthority.public_votes.size() != EXPECTED_PLAYERS:
		error = "D11 client did not converge to eight public votes"
	elif MatchAuthority.is_peer_publicly_alive(_sacrificed_peer_id):
		error = "D11 sacrificed peer remained publicly alive"
	return error

func _try_send_d11_ack() -> void:
	if _final_ack_sent or not _resolution_seen or not _sacrifice_phase_seen:
		return
	var error := _local_resolution_error()
	if not error.is_empty():
		_fail(error)
		return
	_final_ack_sent = true
	_ack_d11_result.rpc_id(
		1,
		_scenario,
		_sacrificed_peer_id,
		_vote_tied,
		MatchAuthority.public_votes.size(),
	)

@rpc("any_peer", "call_remote", "reliable")
func _ack_d11_result(
	scenario_value: String,
	sacrificed_peer_id: int,
	tied: bool,
	public_vote_count: int,
) -> void:
	if _role != "server":
		return
	var sender_id := multiplayer.get_remote_sender_id()
	var error := _client_ack_error(
		scenario_value,
		sacrificed_peer_id,
		tied,
		public_vote_count,
	)
	if not error.is_empty():
		_fail(error)
		return
	if _tie_validated_clients.has(sender_id):
		_fail("D11 server received duplicate client acknowledgement")
		return
	_tie_validated_clients[sender_id] = true
	_try_complete_d11()

func _client_ack_error(
	scenario_value: String,
	sacrificed_peer_id: int,
	tied: bool,
	public_vote_count: int,
) -> String:
	var error := ""
	if scenario_value != _scenario:
		error = "D11 client reported wrong scenario"
	elif sacrificed_peer_id != _sacrificed_peer_id:
		error = "D11 client tie result diverged from server"
	elif tied != _vote_tied or not tied:
		error = "D11 client tie flag diverged from server"
	elif public_vote_count != EXPECTED_PLAYERS:
		error = "D11 client did not report eight public votes"
	return error

func _try_complete_d11() -> void:
	if _d11_completed or not _server_resolution_ready or not _sacrifice_phase_seen:
		return
	if _tie_validated_clients.size() != EXPECTED_CLIENTS:
		return
	var error := _server_final_error()
	if not error.is_empty():
		_fail(error)
		return
	_d11_completed = true
	MatchAuthority._clear_phase_timeout()
	MatchAuthority._sync_phase.rpc(
		int(GameManager.MatchPhase.MATCH_END),
		GameManager.round_number,
	)
	_confirm_d11.rpc(_scenario, _sacrificed_peer_id)
	print(
		"GREEN: Gate D11 server - %s exact-8 tie converged to peer %d"
		% [_scenario, _sacrificed_peer_id]
	)
	_server_quit_delay = 0.50

func _server_final_error() -> String:
	var error := ""
	if _accepted_votes.size() != EXPECTED_PLAYERS:
		error = "D11 server did not accept exactly eight votes"
	elif MatchAuthority.public_votes.size() != EXPECTED_PLAYERS:
		error = "D11 server public vote map did not contain eight votes"
	elif not _vote_tied:
		error = "D11 server did not flag the resolution as tied"
	elif _sacrificed_peer_id not in _expected_tied_targets:
		error = "D11 server sacrificed outside expected tie candidates"
	else:
		var session: MatchSession = MatchAuthority.get("_session")
		if session == null:
			error = "D11 server lost authoritative session"
		elif MatchAuthority.is_peer_publicly_alive(_sacrificed_peer_id):
			error = "D11 public sacrifice state did not update"
	return error

func _sorted_alive_peers() -> Array[int]:
	var peers: Array[int] = []
	for raw_peer_id in NetworkManager.peers.keys():
		var peer_id := int(raw_peer_id)
		if MatchAuthority.is_peer_publicly_alive(peer_id):
			peers.append(peer_id)
	peers.sort()
	return peers

@rpc("authority", "call_remote", "reliable")
func _confirm_d11(scenario_value: String, sacrificed_peer_id: int) -> void:
	if _role != "client":
		return
	if scenario_value != _scenario or sacrificed_peer_id != _sacrificed_peer_id:
		_fail("D11 final confirmation diverged from local tie result")
		return
	print(
		"GREEN: Gate D11 client %d - %s tie matched peer %d"
		% [_client_index, _scenario, sacrificed_peer_id]
	)
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("RED: Gate D11 %s%s - %s" % [_role, _client_suffix(), message])
	get_tree().quit(1)
