extends "res://tests/acceptance/gate_d_full_night_actions_runtime.gd"

const D10_TIMEOUT_SECONDS := 30.0
const ATTEMPT_SETTLE_SECONDS := 0.12
const INVALID_TARGET_PEER_ID := 999999

var _adversarial_started := false
var _primary_voter := 0
var _dead_voter := 0
var _secondary_voter := 0
var _valid_target_a := 0
var _valid_target_b := 0
var _attempt_plan: Array[Dictionary] = []
var _attempt_index := 0
var _current_attempt_label := ""
var _attempt_ack_received := false
var _attempt_settle_delay := -1.0
var _accepted_votes: Dictionary = {}
var _finalized := false

func _ready() -> void:
	super()
	MatchAuthority.vote_accepted.connect(_on_d10_vote_accepted)
	MatchAuthority.phase_synced.connect(_on_d10_phase_synced)

func _process(delta: float) -> void:
	if _server_quit_delay >= 0.0:
		_server_quit_delay -= delta
		if _server_quit_delay <= 0.0:
			get_tree().quit(0)
			return

	_elapsed += delta
	if _elapsed >= D10_TIMEOUT_SECONDS:
		_fail(
			"%s timed out (phase=%d attempt=%d/%d votes=%d)"
			% [
				_role,
				int(GameManager.phase),
				_attempt_index,
				_attempt_plan.size(),
				(MatchAuthority.get("_votes") as Dictionary).size(),
			]
		)
		return

	if _role == "server" and not _match_started:
		_process_server_roster(delta)
	if _role == "server":
		_process_server_phase_fast_forward(delta)
		_process_attempt_settle(delta)
	if _match_started and NightPhaseRules.is_action_phase(GameManager.phase):
		_try_submit_night_action()

func _handle_day_discussion() -> void:
	var validation_error := _local_day_validation_error()
	if not validation_error.is_empty():
		_fail(validation_error)
		return
	if _role == "server" and not _adversarial_started:
		call_deferred("_begin_adversarial_voting")

func _begin_adversarial_voting() -> void:
	if _adversarial_started or GameManager.phase != GameManager.MatchPhase.DAY_DISCUSSION:
		return
	var remote_peers := _remote_alive_peer_ids()
	if remote_peers.size() < 5:
		_fail("D10 needs at least five remote peers")
		return
	_adversarial_started = true
	_primary_voter = remote_peers[0]
	_dead_voter = remote_peers[1]
	_secondary_voter = remote_peers[2]
	_valid_target_a = remote_peers[3]
	_valid_target_b = remote_peers[4]

	var session: MatchSession = MatchAuthority.get("_session")
	var dead_player := session.get_player(_dead_voter) if session != null else null
	if dead_player == null:
		_fail("D10 could not resolve dead voter in authoritative session")
		return
	dead_player.alive = false
	MatchAuthority._sync_night_resolution.rpc([_dead_voter])

	_attempt_plan = [
		{
			"label": "self_vote",
			"actor": _primary_voter,
			"target": _primary_voter,
		},
		{
			"label": "first_valid_vote",
			"actor": _primary_voter,
			"target": _valid_target_a,
		},
		{
			"label": "duplicate_replace",
			"actor": _primary_voter,
			"target": _valid_target_b,
		},
		{
			"label": "dead_voter",
			"actor": _dead_voter,
			"target": _valid_target_a,
		},
		{
			"label": "dead_target",
			"actor": _secondary_voter,
			"target": _dead_voter,
		},
		{
			"label": "invalid_target",
			"actor": _secondary_voter,
			"target": INVALID_TARGET_PEER_ID,
		},
		{
			"label": "post_deadline",
			"actor": _secondary_voter,
			"target": _valid_target_a,
		},
	]
	MatchAuthority.request_begin_voting()

func _on_d10_phase_synced(phase_value: int) -> void:
	if _role != "server" or not _adversarial_started:
		return
	if phase_value == int(GameManager.MatchPhase.VOTING) and _attempt_index == 0:
		call_deferred("_dispatch_current_attempt")

func _dispatch_current_attempt() -> void:
	if _role != "server" or _finalized:
		return
	if _attempt_index >= _attempt_plan.size():
		_finish_d10()
		return

	var attempt: Dictionary = _attempt_plan[_attempt_index]
	var label := str(attempt.get("label", ""))
	if label == "post_deadline" and GameManager.phase == GameManager.MatchPhase.VOTING:
		MatchAuthority._clear_phase_timeout()
		MatchAuthority._sync_phase.rpc(
			int(GameManager.MatchPhase.SACRIFICE),
			GameManager.round_number,
		)
		call_deferred("_dispatch_current_attempt")
		return
	if label != "post_deadline" and GameManager.phase != GameManager.MatchPhase.VOTING:
		_fail("D10 left voting before adversarial attempts completed")
		return

	_current_attempt_label = label
	_attempt_ack_received = false
	_run_d10_vote_attempt.rpc_id(
		int(attempt.get("actor", 0)),
		int(attempt.get("target", 0)),
		label,
	)

@rpc("authority", "call_remote", "reliable")
func _run_d10_vote_attempt(target_peer_id: int, label: String) -> void:
	if _role != "client":
		return
	MatchAuthority._request_vote.rpc_id(1, target_peer_id)
	_ack_d10_vote_attempt.rpc_id(1, label)

@rpc("any_peer", "call_remote", "reliable")
func _ack_d10_vote_attempt(label: String) -> void:
	if _role != "server" or label != _current_attempt_label:
		return
	var attempt: Dictionary = _attempt_plan[_attempt_index]
	if multiplayer.get_remote_sender_id() != int(attempt.get("actor", 0)):
		_fail("D10 attempt acknowledgement came from wrong peer")
		return
	_attempt_ack_received = true
	_attempt_settle_delay = ATTEMPT_SETTLE_SECONDS

func _process_attempt_settle(delta: float) -> void:
	if not _attempt_ack_received or _attempt_settle_delay < 0.0:
		return
	_attempt_settle_delay -= delta
	if _attempt_settle_delay > 0.0:
		return
	_attempt_settle_delay = -1.0
	_attempt_ack_received = false
	var error := _current_attempt_validation_error()
	if not error.is_empty():
		_fail(error)
		return
	_attempt_index += 1
	_current_attempt_label = ""
	call_deferred("_dispatch_current_attempt")

func _current_attempt_validation_error() -> String:
	var label := str(_attempt_plan[_attempt_index].get("label", ""))
	var votes: Dictionary = MatchAuthority.get("_votes")
	var error := ""
	match label:
		"self_vote":
			if votes.has(_primary_voter):
				error = "server accepted a self-vote"
		"first_valid_vote":
			if int(votes.get(_primary_voter, 0)) != _valid_target_a:
				error = "server did not accept the first valid vote"
			elif int(_accepted_votes.get(_primary_voter, 0)) != _valid_target_a:
				error = "vote_accepted did not report the first valid vote"
		"duplicate_replace":
			if int(votes.get(_primary_voter, 0)) != _valid_target_a:
				error = "duplicate RPC replaced the original vote"
			elif _accepted_votes.size() != 1:
				error = "duplicate RPC emitted an extra accepted vote"
		"dead_voter":
			if votes.has(_dead_voter):
				error = "dead voter was accepted"
		"dead_target", "invalid_target":
			if votes.has(_secondary_voter):
				error = "invalid target attempt created a vote"
		"post_deadline":
			if GameManager.phase != GameManager.MatchPhase.SACRIFICE:
				error = "post-deadline attempt did not run outside voting"
			elif votes.has(_secondary_voter):
				error = "post-deadline vote was accepted"
			elif int(votes.get(_primary_voter, 0)) != _valid_target_a:
				error = "post-deadline attempt mutated existing vote state"
	return error

func _on_d10_vote_accepted(voter_peer_id: int, target_peer_id: int) -> void:
	if _role != "server":
		return
	_accepted_votes[voter_peer_id] = target_peer_id

func _finish_d10() -> void:
	if _finalized:
		return
	var votes: Dictionary = MatchAuthority.get("_votes")
	if votes.size() != 1 or int(votes.get(_primary_voter, 0)) != _valid_target_a:
		_fail("D10 final vote state was not exactly the first valid vote")
		return
	if _accepted_votes.size() != 1:
		_fail("D10 accepted more than one adversarial vote")
		return
	_finalized = true
	MatchAuthority._clear_phase_timeout()
	MatchAuthority._sync_phase.rpc(
		int(GameManager.MatchPhase.MATCH_END),
		GameManager.round_number,
	)
	_confirm_d10.rpc()
	print("GREEN: Gate D10 server - exact-8 adversarial vote authorization held")
	_server_quit_delay = 0.50

func _remote_alive_peer_ids() -> Array[int]:
	var peer_ids: Array[int] = []
	var local_peer_id := multiplayer.get_unique_id()
	for raw_peer_id in NetworkManager.peers.keys():
		var peer_id := int(raw_peer_id)
		if peer_id != local_peer_id and MatchAuthority.is_peer_publicly_alive(peer_id):
			peer_ids.append(peer_id)
	peer_ids.sort()
	return peer_ids

@rpc("authority", "call_remote", "reliable")
func _confirm_d10() -> void:
	if _role != "client":
		return
	print("GREEN: Gate D10 client %d - adversarial vote state matched" % _client_index)
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("RED: Gate D10 %s%s - %s" % [_role, _client_suffix(), message])
	get_tree().quit(1)
