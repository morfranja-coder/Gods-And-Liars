extends "res://tests/acceptance/gate_d_role_reveal_ack.gd"

const D8_TIMEOUT_SECONDS := 25.0

var _security_started := false
var _privacy_reports: Dictionary = {}
var _attack_results: Dictionary = {}
var _expected_attacks: Dictionary = {}
var _valid_decider_action_seen := false
var _d8_completed := false

func _ready() -> void:
	super()
	MatchAuthority.night_action_accepted.connect(_on_night_action_accepted)
	MatchAuthority.night_action_result_received.connect(_on_night_action_result)

func _process(delta: float) -> void:
	if _server_quit_delay >= 0.0:
		_server_quit_delay -= delta
		if _server_quit_delay <= 0.0:
			get_tree().quit(0)
			return

	_elapsed += delta
	if _elapsed >= D8_TIMEOUT_SECONDS:
		_fail("%s timed out" % _role)
		return
	if _role == "server" and not _match_started:
		_process_server_roster(delta)

func _try_complete_server() -> void:
	if _security_started or not _server_first_night_ready:
		return
	if _validated_clients.size() != EXPECTED_CLIENTS:
		return
	_security_started = true
	MatchAuthority._clear_phase_timeout()
	call_deferred("_begin_security_checks")

func _begin_security_checks() -> void:
	if _role != "server":
		return
	if GameManager.phase != GameManager.MatchPhase.HERETIC_ACTION:
		_fail("security checks did not start during heretic action")
		return
	var decider := MatchAuthority.current_heretic_decider_peer_id
	if decider <= 0:
		_fail("server has no authoritative heretic decider")
		return
	_privacy_reports.clear()
	_request_privacy_report.rpc()
	await get_tree().create_timer(0.35).timeout
	if not _validate_privacy_reports(decider):
		return
	_run_invalid_and_valid_night_attempts(decider)

@rpc("authority", "call_remote", "reliable")
func _request_privacy_report() -> void:
	if _role != "client":
		return
	_submit_privacy_report.rpc_id(
		1,
		int(MatchAuthority.local_role),
		MatchAuthority.current_heretic_decider_peer_id,
	)

@rpc("any_peer", "call_remote", "reliable")
func _submit_privacy_report(role_value: int, decider_peer_id: int) -> void:
	if _role != "server":
		return
	var sender_id := multiplayer.get_remote_sender_id()
	_privacy_reports[sender_id] = {
		"role": role_value,
		"decider": decider_peer_id,
	}

func _validate_privacy_reports(decider_peer_id: int) -> bool:
	if _privacy_reports.size() != EXPECTED_CLIENTS:
		_fail("server did not receive seven remote decider privacy reports")
		return false
	for raw_peer_id in _privacy_reports.keys():
		var peer_id := int(raw_peer_id)
		if peer_id == multiplayer.get_unique_id():
			_fail("server process must not be evaluated as a remote privacy client")
			return false
		var report: Dictionary = _privacy_reports[raw_peer_id]
		var authoritative_role := MatchAuthority.server_role_for_peer(peer_id)
		if int(report.get("role", -1)) != int(authoritative_role):
			_fail("client role diverged during D8 privacy check")
			return false
		var visible_decider := int(report.get("decider", -1))
		if authoritative_role == PlayerState.Role.HERETIC:
			if visible_decider != decider_peer_id:
				_fail("living heretic did not receive the private decider")
				return false
		elif visible_decider != 0:
			_fail("non-heretic learned the private decider")
			return false
	return true

func _run_invalid_and_valid_night_attempts(decider_peer_id: int) -> void:
	var faithful_peer := _first_remote_peer_with_role(PlayerState.Role.FAITHFUL)
	var non_decider := _other_heretic_peer(decider_peer_id)
	var faithful_target := _first_peer_not_role(PlayerState.Role.HERETIC, faithful_peer)
	if faithful_peer <= 0 or faithful_target <= 0 or non_decider <= 0:
		_fail("could not build D8 adversarial actors")
		return

	_expected_attacks["faithful"] = false
	_command_night_attempt(faithful_peer, faithful_target, "faithful")

	_expected_attacks["non_decider"] = false
	_command_night_attempt(non_decider, faithful_target, "non_decider")

	_expected_attacks["heretic_target"] = false
	_command_night_attempt(decider_peer_id, non_decider, "heretic_target")

	_expected_attacks["valid_decider"] = true
	_command_night_attempt(decider_peer_id, faithful_target, "valid_decider")

func _command_night_attempt(actor_peer_id: int, target_peer_id: int, label: String) -> void:
	if actor_peer_id == multiplayer.get_unique_id():
		_pending_attack_label = label
		MatchAuthority._server_submit_night_action(actor_peer_id, target_peer_id)
		return
	_run_night_attempt.rpc_id(actor_peer_id, target_peer_id, label)

var _pending_attack_label := ""

@rpc("authority", "call_remote", "reliable")
func _run_night_attempt(target_peer_id: int, label: String) -> void:
	if _role != "client":
		return
	_pending_attack_label = label
	MatchAuthority._request_night_action.rpc_id(1, target_peer_id)

func _on_night_action_result(accepted: bool, _target_peer_id: int) -> void:
	if _pending_attack_label.is_empty():
		return
	var label := _pending_attack_label
	_pending_attack_label = ""
	if _role == "server":
		_record_attack_result(label, accepted)
	else:
		_report_attack_result.rpc_id(1, label, accepted)

@rpc("any_peer", "call_remote", "reliable")
func _report_attack_result(label: String, accepted: bool) -> void:
	if _role != "server":
		return
	_record_attack_result(label, accepted)

func _record_attack_result(label: String, accepted: bool) -> void:
	if not _expected_attacks.has(label):
		_fail("received unexpected D8 attack result")
		return
	_attack_results[label] = accepted
	if label == "valid_decider" and accepted:
		_valid_decider_action_seen = true
	_try_finish_d8()

func _on_night_action_accepted(actor_peer_id: int, _target_peer_id: int) -> void:
	if _role != "server":
		return
	if actor_peer_id != MatchAuthority.current_heretic_decider_peer_id:
		_fail("server accepted night action from non-decider")
		return

func _try_finish_d8() -> void:
	if _d8_completed or _attack_results.size() != _expected_attacks.size():
		return
	for label in _expected_attacks.keys():
		if bool(_attack_results.get(label, not bool(_expected_attacks[label]))) != bool(_expected_attacks[label]):
			_fail("D8 attack result mismatch for %s" % label)
			return
	if not _valid_decider_action_seen:
		_fail("valid decider path was never accepted")
		return
	_d8_completed = true
	MatchAuthority._clear_phase_timeout()
	MatchAuthority._sync_phase.rpc(
		int(GameManager.MatchPhase.MATCH_END),
		GameManager.round_number,
	)
	_confirm_d8.rpc()
	print("GREEN: Gate D8 server - exact-8 decider privacy and night authorization held")
	_server_quit_delay = 0.50

func _first_remote_peer_with_role(role_value: PlayerState.Role) -> int:
	for raw_peer_id in NetworkManager.peers.keys():
		var peer_id := int(raw_peer_id)
		if peer_id == multiplayer.get_unique_id():
			continue
		if MatchAuthority.server_role_for_peer(peer_id) == role_value:
			return peer_id
	return 0

func _other_heretic_peer(decider_peer_id: int) -> int:
	for raw_peer_id in NetworkManager.peers.keys():
		var peer_id := int(raw_peer_id)
		if (
			peer_id != decider_peer_id
			and MatchAuthority.server_role_for_peer(peer_id) == PlayerState.Role.HERETIC
		):
			return peer_id
	return 0

func _first_peer_not_role(role_value: PlayerState.Role, excluded_peer_id: int) -> int:
	for raw_peer_id in NetworkManager.peers.keys():
		var peer_id := int(raw_peer_id)
		if peer_id == excluded_peer_id:
			continue
		if MatchAuthority.server_role_for_peer(peer_id) != role_value:
			return peer_id
	return 0

@rpc("authority", "call_remote", "reliable")
func _confirm_d8() -> void:
	if _role != "client":
		return
	print("GREEN: Gate D8 client %d - adversarial night checks matched" % _client_index)
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error("RED: Gate D8 %s%s - %s" % [_role, _client_suffix(), message])
	get_tree().quit(1)
