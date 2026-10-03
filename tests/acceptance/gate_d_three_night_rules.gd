extends "res://tests/acceptance/gate_d_role_reveal_ack.gd"

const D9_TIMEOUT_SECONDS := 35.0
const FINAL_ROUND := 3
const FAST_FORWARD_DELAY_SECONDS := 0.20
const NEXT_NIGHT_DELAY_SECONDS := 0.30

var _plan_round := 0
var _plan_heretic_target := 0
var _plan_healer_target := 0
var _plan_inquisitor_target := 0
var _server_phase_advance_delay := -1.0
var _server_next_night_delay := -1.0
var _submitted_action_keys: Dictionary = {}
var _accepted_action_keys: Dictionary = {}
var _accepted_action_targets: Dictionary = {}
var _pending_action_key := ""
var _round3_healer_self_attempted := false
var _round3_healer_self_rejected := false
var _server_round3_self_rejection_peer := 0
var _server_accepted_actions: Dictionary = {}
var _server_deciders: Dictionary = {}
var _night_kills_by_round: Dictionary = {}
var _day_rounds_seen: Dictionary = {}
var _local_deciders: Dictionary = {}
var _priest_warning_round1 := 0
var _investigation_by_round: Dictionary = {}
var _final_ack_sent := false
var _server_final_ready := false
var _d9_completed := false
var _final_validated_clients: Dictionary = {}

func _ready() -> void:
	super()
	MatchAuthority.night_action_result_received.connect(_on_d9_night_action_result)
	MatchAuthority.night_action_accepted.connect(_on_d9_night_action_accepted)
	MatchAuthority.night_resolution_received.connect(_on_d9_night_resolution)
	MatchAuthority.private_priest_warning_received.connect(_on_d9_priest_warning)
	MatchAuthority.private_investigation_received.connect(_on_d9_investigation)

func _process(delta: float) -> void:
	if _server_quit_delay >= 0.0:
		_server_quit_delay -= delta
		if _server_quit_delay <= 0.0:
			get_tree().quit(0)
			return

	_elapsed += delta
	if _elapsed >= D9_TIMEOUT_SECONDS:
		_fail(
			"%s timed out (round=%d phase=%d night_resolutions=%d final_acks=%d)"
			% [
				_role,
				GameManager.round_number,
				int(GameManager.phase),
				_night_kills_by_round.size(),
				_final_validated_clients.size(),
			]
		)
		return

	if _role == "server" and not _match_started:
		_process_server_roster(delta)
	if _role == "server":
		_process_server_phase_fast_forward(delta)
		_process_server_next_night(delta)

func _on_phase_synced(phase_value: int) -> void:
	var round_value := GameManager.round_number
	if phase_value == int(GameManager.MatchPhase.GOD_INTRO):
		_schedule_server_phase_advance()
	elif phase_value == int(GameManager.MatchPhase.NIGHT_START):
		_schedule_server_phase_advance()
	elif phase_value == int(GameManager.MatchPhase.HERETIC_ACTION):
		if _role == "server":
			_build_and_broadcast_round_plan()
		if MatchAuthority.local_role == PlayerState.Role.HERETIC:
			_local_deciders[round_value] = MatchAuthority.current_heretic_decider_peer_id
		call_deferred("_try_submit_planned_action")
	elif phase_value == int(GameManager.MatchPhase.HEALER_ACTION):
		if round_value == 1:
			_schedule_server_phase_advance()
		else:
			call_deferred("_try_submit_planned_action")
	elif phase_value == int(GameManager.MatchPhase.INQUISITOR_ACTION):
		if round_value == 1:
			_schedule_server_phase_advance()
		else:
			call_deferred("_try_submit_planned_action")
	elif phase_value == int(GameManager.MatchPhase.DAY_ANNOUNCEMENT):
		call_deferred("_handle_day_announcement")

func _build_and_broadcast_round_plan() -> void:
	var round_value := GameManager.round_number
	if round_value < 1 or round_value > FINAL_ROUND:
		_fail("server reached unexpected round while planning night")
		return
	var heretics := _alive_role_peers(PlayerState.Role.HERETIC)
	var healers := _alive_role_peers(PlayerState.Role.HEALER)
	var inquisitors := _alive_role_peers(PlayerState.Role.INQUISITOR)
	var faithful := _alive_role_peers(PlayerState.Role.FAITHFUL)
	if heretics.size() != 2 or healers.size() != 1 or inquisitors.size() != 1:
		_fail("core night roles did not survive to planned round")
		return
	if faithful.is_empty():
		_fail("no faithful target available for multi-night plan")
		return

	var decider := MatchAuthority.current_heretic_decider_peer_id
	if decider != NightRoundRules.choose_heretic_decider(
		(MatchAuthority.get("_session") as MatchSession).players,
		round_value,
	):
		_fail("authoritative heretic decider diverged from NightRoundRules")
		return
	_server_deciders[round_value] = decider

	var heretic_target := faithful[0]
	var healer_target := heretic_target
	if round_value == 2:
		healer_target = healers[0]
	var inquisitor_target := heretics[(round_value - 1) % heretics.size()]
	_sync_d9_plan.rpc(
		round_value,
		heretic_target,
		healer_target,
		inquisitor_target,
	)

@rpc("authority", "call_local", "reliable")
func _sync_d9_plan(
	round_value: int,
	heretic_target: int,
	healer_target: int,
	inquisitor_target: int,
) -> void:
	_plan_round = round_value
	_plan_heretic_target = heretic_target
	_plan_healer_target = healer_target
	_plan_inquisitor_target = inquisitor_target
	call_deferred("_try_submit_planned_action")

func _try_submit_planned_action() -> void:
	if not NightPhaseRules.is_action_phase(GameManager.phase):
		return
	var round_value := GameManager.round_number
	if _plan_round != round_value:
		return
	var local_peer_id := multiplayer.get_unique_id()
	if not MatchAuthority.is_peer_publicly_alive(local_peer_id):
		return
	var required_role := NightPhaseRules.role_for_phase(GameManager.phase)
	if required_role != MatchAuthority.local_role:
		return

	if required_role == PlayerState.Role.HERETIC:
		if local_peer_id != MatchAuthority.current_heretic_decider_peer_id:
			return
		_submit_expected_action(
			_action_key(round_value, "heretic"),
			_plan_heretic_target,
		)
		return

	if required_role == PlayerState.Role.HEALER:
		if round_value == 1:
			return
		if round_value == 3 and not _round3_healer_self_attempted:
			_round3_healer_self_attempted = true
			_submit_expected_action("3:healer_self_retry", local_peer_id)
			return
		if round_value == 3 and not _round3_healer_self_rejected:
			return
		_submit_expected_action(
			_action_key(round_value, "healer"),
			_plan_healer_target,
		)
		return

	if required_role == PlayerState.Role.INQUISITOR:
		if round_value == 1:
			return
		_submit_expected_action(
			_action_key(round_value, "inquisitor"),
			_plan_inquisitor_target,
		)

func _submit_expected_action(key: String, target_peer_id: int) -> void:
	if _submitted_action_keys.has(key) or not _pending_action_key.is_empty():
		return
	if target_peer_id <= 0:
		_fail("planned night action had no target")
		return
	_submitted_action_keys[key] = true
	_pending_action_key = key
	MatchAuthority.submit_local_night_target(target_peer_id)

func _on_d9_night_action_result(accepted: bool, target_peer_id: int) -> void:
	if _pending_action_key.is_empty():
		return
	var key := _pending_action_key
	_pending_action_key = ""

	if key == "3:healer_self_retry":
		if accepted:
			_fail("second healer self-save was accepted on round three")
			return
		_round3_healer_self_rejected = true
		_report_round3_self_save_rejection()
		call_deferred("_try_submit_planned_action")
		return

	if not accepted:
		_fail("planned night action was rejected: %s" % key)
		return
	_accepted_action_keys[key] = true
	_accepted_action_targets[key] = target_peer_id

func _report_round3_self_save_rejection() -> void:
	var local_peer_id := multiplayer.get_unique_id()
	if _role == "server":
		_server_round3_self_rejection_peer = local_peer_id
	else:
		_report_d9_self_save_rejection.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func _report_d9_self_save_rejection() -> void:
	if _role != "server":
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if MatchAuthority.server_role_for_peer(sender_id) != PlayerState.Role.HEALER:
		_fail("non-healer reported a rejected self-save")
		return
	_server_round3_self_rejection_peer = sender_id

func _on_d9_night_action_accepted(actor_peer_id: int, target_peer_id: int) -> void:
	if _role != "server":
		return
	var round_value := GameManager.round_number
	var accepted: Dictionary = _server_accepted_actions.get(round_value, {})
	accepted[actor_peer_id] = target_peer_id
	_server_accepted_actions[round_value] = accepted

	var required_role := NightPhaseRules.role_for_phase(GameManager.phase)
	if MatchAuthority.server_role_for_peer(actor_peer_id) != required_role:
		_fail("server accepted action from wrong role during D9")
		return
	if required_role == PlayerState.Role.HERETIC:
		if actor_peer_id != MatchAuthority.current_heretic_decider_peer_id:
			_fail("server accepted non-decider heretic during D9")
			return
		if target_peer_id != _plan_heretic_target:
			_fail("server accepted heretic target outside D9 plan")
			return
	elif required_role == PlayerState.Role.HEALER:
		if target_peer_id != _plan_healer_target:
			_fail("server accepted healer target outside D9 plan")
			return
	elif required_role == PlayerState.Role.INQUISITOR:
		if target_peer_id != _plan_inquisitor_target:
			_fail("server accepted inquisitor target outside D9 plan")
			return
	_schedule_server_phase_advance()

func _on_d9_night_resolution(killed_peer_ids: Array[int]) -> void:
	_night_kills_by_round[GameManager.round_number] = killed_peer_ids.duplicate()

func _on_d9_priest_warning(target_peer_id: int) -> void:
	if GameManager.round_number == 1:
		_priest_warning_round1 = target_peer_id

func _on_d9_investigation(target_peer_id: int, is_heretic: bool) -> void:
	_investigation_by_round[GameManager.round_number] = {
		"target": target_peer_id,
		"is_heretic": is_heretic,
	}

func _handle_day_announcement() -> void:
	var round_value := GameManager.round_number
	var local_error := _local_round_validation_error(round_value)
	if not local_error.is_empty():
		_fail(local_error)
		return
	_day_rounds_seen[round_value] = true

	if _role == "server":
		var server_error := _server_round_validation_error(round_value)
		if not server_error.is_empty():
			_fail(server_error)
			return

	if round_value < FINAL_ROUND:
		if _role == "server":
			MatchAuthority._clear_phase_timeout()
			_server_next_night_delay = NEXT_NIGHT_DELAY_SECONDS
		return

	if _role == "server":
		_server_final_ready = true
		_try_complete_d9_server()
	elif not _final_ack_sent:
		_final_ack_sent = true
		_send_d9_final_ack()

func _local_round_validation_error(round_value: int) -> String:
	if not _night_kills_by_round.has(round_value):
		return "client missed night resolution for round %d" % round_value
	var killed: Array = _night_kills_by_round[round_value]
	if round_value == 1:
		if not killed.is_empty():
			return "first night killed a player"
		if not MatchAuthority.last_night_was_first:
			return "first night public report was not marked first"
		if not MatchAuthority.last_night_priest_saved:
			return "first night did not report priest rescue"
		if MatchAuthority.local_role == PlayerState.Role.HEALER:
			if _priest_warning_round1 != _plan_heretic_target:
				return "priest warning did not match first-night target"
		if MatchAuthority.local_role == PlayerState.Role.INQUISITOR:
			if _investigation_by_round.has(1):
				return "inquisitor received a first-night investigation"
	elif round_value == 2:
		if killed.size() != 1 or int(killed[0]) != _plan_heretic_target:
			return "round-two kill did not match unprotected heretic target"
		if MatchAuthority.last_night_was_first:
			return "round two was incorrectly marked first night"
		if MatchAuthority.local_role == PlayerState.Role.HEALER:
			var key := _action_key(2, "healer")
			if not _accepted_action_keys.has(key):
				return "healer self-save was not accepted on round two"
			if int(_accepted_action_targets.get(key, 0)) != multiplayer.get_unique_id():
				return "round-two healer action was not a self-save"
		if MatchAuthority.local_role == PlayerState.Role.INQUISITOR:
			if not _valid_investigation(2):
				return "round-two inquisitor result was missing or incorrect"
	elif round_value == 3:
		if not killed.is_empty():
			return "round-three protected target was killed"
		if MatchAuthority.local_role == PlayerState.Role.HEALER:
			if not _round3_healer_self_rejected:
				return "healer did not observe second self-save rejection"
			var key := _action_key(3, "healer")
			if not _accepted_action_keys.has(key):
				return "healer fallback action was not accepted on round three"
			if int(_accepted_action_targets.get(key, 0)) != _plan_healer_target:
				return "round-three healer fallback target diverged"
		if MatchAuthority.local_role == PlayerState.Role.INQUISITOR:
			if not _valid_investigation(3):
				return "round-three inquisitor result was missing or incorrect"
	return ""

func _server_round_validation_error(round_value: int) -> String:
	var accepted: Dictionary = _server_accepted_actions.get(round_value, {})
	var expected_count := 1 if round_value == 1 else 3
	if accepted.size() != expected_count:
		return "server accepted %d actions on round %d; expected %d" % [
			accepted.size(),
			round_value,
			expected_count,
		]
	var killed: Array = _night_kills_by_round.get(round_value, [])
	if round_value == 1 and not killed.is_empty():
		return "server observed a first-night kill"
	if round_value == 2 and killed.size() != 1:
		return "server did not observe exactly one round-two kill"
	if round_value == 3:
		if not killed.is_empty():
			return "server observed a round-three kill despite priest protection"
		if not bool(MatchAuthority.get("_healer_self_save_used")):
			return "server lost healer self-save consumption state"
		var healer := _alive_role_peers(PlayerState.Role.HEALER)
		if healer.size() != 1 or _server_round3_self_rejection_peer != healer[0]:
			return "server did not receive healer round-three self-save rejection proof"
	if not _public_alive_matches_session():
		return "server public alive state diverged from session on round %d" % round_value
	return ""

func _valid_investigation(round_value: int) -> bool:
	if not _investigation_by_round.has(round_value):
		return false
	var report: Dictionary = _investigation_by_round[round_value]
	return (
		int(report.get("target", 0)) == _plan_inquisitor_target
		and bool(report.get("is_heretic", false))
	)

func _schedule_server_phase_advance() -> void:
	if _role == "server":
		_server_phase_advance_delay = FAST_FORWARD_DELAY_SECONDS

func _process_server_phase_fast_forward(delta: float) -> void:
	if not _match_started or _server_phase_advance_delay < 0.0:
		return
	_server_phase_advance_delay -= delta
	if _server_phase_advance_delay > 0.0:
		return
	_server_phase_advance_delay = -1.0
	var phase := GameManager.phase
	if phase not in [
		GameManager.MatchPhase.GOD_INTRO,
		GameManager.MatchPhase.NIGHT_START,
		GameManager.MatchPhase.HERETIC_ACTION,
		GameManager.MatchPhase.HEALER_ACTION,
		GameManager.MatchPhase.INQUISITOR_ACTION,
	]:
		return
	MatchAuthority._clear_phase_timeout()
	MatchAuthority._handle_phase_timeout(phase)

func _process_server_next_night(delta: float) -> void:
	if _server_next_night_delay < 0.0:
		return
	_server_next_night_delay -= delta
	if _server_next_night_delay > 0.0:
		return
	_server_next_night_delay = -1.0
	if GameManager.phase != GameManager.MatchPhase.DAY_ANNOUNCEMENT:
		_fail("server left day announcement before D9 next-night transition")
		return
	GameManager.round_number += 1
	MatchAuthority._start_night()

func _send_d9_final_ack() -> void:
	var d1 := int(_local_deciders.get(1, 0))
	var d2 := int(_local_deciders.get(2, 0))
	var d3 := int(_local_deciders.get(3, 0))
	_ack_d9_final.rpc_id(
		1,
		int(MatchAuthority.local_role),
		_day_rounds_seen.size(),
		_night_kills_by_round.size(),
		_investigation_by_round.size(),
		_priest_warning_round1 > 0,
		_round3_healer_self_rejected,
		d1,
		d2,
		d3,
	)

@rpc("any_peer", "call_remote", "reliable")
func _ack_d9_final(
	role_value: int,
	day_round_count: int,
	night_resolution_count: int,
	investigation_count: int,
	priest_warning_seen: bool,
	healer_second_self_save_rejected: bool,
	decider_round1: int,
	decider_round2: int,
	decider_round3: int,
) -> void:
	if _role != "server":
		return
	var sender_id := multiplayer.get_remote_sender_id()
	var expected_role := MatchAuthority.server_role_for_peer(sender_id)
	if role_value != int(expected_role):
		_fail("D9 client role diverged from authoritative role")
		return
	if day_round_count != FINAL_ROUND or night_resolution_count != FINAL_ROUND:
		_fail("D9 client missed one of three nights")
		return
	if expected_role == PlayerState.Role.HEALER:
		if not priest_warning_seen or not healer_second_self_save_rejected:
			_fail("D9 healer client missed warning or second self-save rejection")
			return
	elif expected_role == PlayerState.Role.INQUISITOR:
		if investigation_count != 2:
			_fail("D9 inquisitor did not receive exactly two investigations")
			return
	elif expected_role == PlayerState.Role.HERETIC:
		if (
			decider_round1 <= 0
			or decider_round2 <= 0
			or decider_round3 <= 0
			or decider_round1 == decider_round2
			or decider_round1 != decider_round3
		):
			_fail("D9 heretic client did not observe 1-2-1 decider rotation")
			return
	if _final_validated_clients.has(sender_id):
		_fail("server received duplicate D9 final acknowledgement")
		return
	_final_validated_clients[sender_id] = true
	_try_complete_d9_server()

func _try_complete_d9_server() -> void:
	if _d9_completed or not _server_final_ready:
		return
	if _final_validated_clients.size() != EXPECTED_CLIENTS:
		return
	var error := _server_final_validation_error()
	if not error.is_empty():
		_fail(error)
		return
	_d9_completed = true
	MatchAuthority._clear_phase_timeout()
	MatchAuthority._sync_phase.rpc(
		int(GameManager.MatchPhase.MATCH_END),
		GameManager.round_number,
	)
	_confirm_d9.rpc()
	print("GREEN: Gate D9 server - exact-8 three-night rules and healer self-save held")
	_server_quit_delay = 0.50

func _server_final_validation_error() -> String:
	if _night_kills_by_round.size() != FINAL_ROUND:
		return "server did not resolve all three D9 nights"
	if _server_deciders.size() != FINAL_ROUND:
		return "server did not record all three heretic deciders"
	var d1 := int(_server_deciders.get(1, 0))
	var d2 := int(_server_deciders.get(2, 0))
	var d3 := int(_server_deciders.get(3, 0))
	if d1 <= 0 or d2 <= 0 or d3 <= 0 or d1 == d2 or d1 != d3:
		return "server heretic decider rotation was not 1-2-1"
	if not bool(MatchAuthority.get("_healer_self_save_used")):
		return "healer self-save was not consumed after round two"
	return ""

func _action_key(round_value: int, action_name: String) -> String:
	return "%d:%s" % [round_value, action_name]

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

func _public_alive_matches_session() -> bool:
	var session: MatchSession = MatchAuthority.get("_session")
	if session == null:
		return false
	for player in session.players:
		if MatchAuthority.is_peer_publicly_alive(player.peer_id) != player.alive:
			return false
	return true

@rpc("authority", "call_remote", "reliable")
func _confirm_d9() -> void:
	if _role != "client":
		return
	print("GREEN: Gate D9 client %d - three-night state matched" % _client_index)
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("RED: Gate D9 %s%s - %s" % [_role, _client_suffix(), message])
	get_tree().quit(1)
