extends Node

const PORT := 24685
const TIMEOUT_SECONDS := 18.0
const HOST_STEAM_ID := 940000
const CLIENT_STEAM_ID_BASE := 940000
const EXPECTED_PLAYERS := 8
const EXPECTED_CLIENTS := 7
const EXPECTED_ROUND := 1
const FAST_FORWARD_DELAY_SECONDS := 0.5

var _role := ""
var _client_index := 0
var _elapsed := 0.0
var _roster_ready_delay := -1.0
var _server_phase_advance_delay := -1.0
var _match_started := false
var _role_received := false
var _action_sent := false
var _action_accepted := false
var _priest_warning_received := false
var _priest_warning_target := 0
var _investigation_received := false
var _investigation_target := 0
var _investigation_is_heretic := false
var _day_ack_sent := false
var _server_day_ready := false
var _completed := false
var _server_quit_delay := -1.0
var _visited_phases: Array[int] = []
var _validated_clients: Dictionary = {}
var _registered_client_indices: Dictionary = {}

func _ready() -> void:
	_parse_args()
	if _role not in ["server", "client"]:
		_fail("missing or invalid role argument")
		return
	if _role == "client" and (_client_index < 1 or _client_index > EXPECTED_CLIENTS):
		_fail("client index must be between 1 and %d" % EXPECTED_CLIENTS)
		return

	NetworkManager.reset()
	MatchAuthority.reset()
	GameManager.reset_match()
	Steamworks.steam_id = _local_steam_id()
	Steamworks.persona_name = _local_display_name()
	MatchAuthority.private_role_received.connect(_on_private_role_received)
	MatchAuthority.private_priest_warning_received.connect(_on_private_priest_warning_received)
	MatchAuthority.phase_synced.connect(_on_phase_synced)
	MatchAuthority.night_action_result_received.connect(_on_night_action_result_received)
	MatchAuthority.private_investigation_received.connect(_on_private_investigation_received)

	var peer := ENetMultiplayerPeer.new()
	var error := OK
	if _role == "server":
		NetworkManager.is_host = true
		NetworkManager.register_peer(1, HOST_STEAM_ID, "D5 Host", 0)
		error = peer.create_server(PORT, EXPECTED_PLAYERS)
	else:
		_disconnect_steam_identity_handshake()
		multiplayer.connected_to_server.connect(_on_connected_to_server)
		error = peer.create_client("127.0.0.1", PORT)
	if error != OK:
		_fail("failed to create %s peer: %s" % [_role, error_string(error)])
		return

	multiplayer.multiplayer_peer = peer
	print("D5 %s%s: transport started" % [_role.to_upper(), _client_suffix()])

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= TIMEOUT_SECONDS:
		_fail("%s timed out" % _role)
		return

	if _role == "server" and not _match_started:
		_process_server_roster(delta)
	if _role == "server":
		_process_server_phase_fast_forward(delta)
	if _match_started and NightPhaseRules.is_action_phase(GameManager.phase):
		_try_submit_night_action()

	if _server_quit_delay >= 0.0:
		_server_quit_delay -= delta
		if _server_quit_delay <= 0.0:
			get_tree().quit(0)

func _parse_args() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		return
	_role = str(args[0]).strip_edges().to_lower()
	if args.size() > 1 and str(args[1]).is_valid_int():
		_client_index = int(args[1])

func _local_steam_id() -> int:
	return HOST_STEAM_ID if _role == "server" else CLIENT_STEAM_ID_BASE + _client_index

func _local_display_name() -> String:
	return "D5 Host" if _role == "server" else "D5 Client %d" % _client_index

func _client_suffix() -> String:
	return "" if _role == "server" else " %d" % _client_index

func _disconnect_steam_identity_handshake() -> void:
	var handler := Callable(NetworkManager, "_on_connected_to_server")
	if multiplayer.connected_to_server.is_connected(handler):
		multiplayer.connected_to_server.disconnect(handler)

func _on_connected_to_server() -> void:
	_register_qa_client.rpc_id(1, _client_index)

@rpc("any_peer", "call_remote", "reliable")
func _register_qa_client(client_index: int) -> void:
	if _role != "server":
		return
	if client_index < 1 or client_index > EXPECTED_CLIENTS:
		_fail("server received invalid client index")
		return
	if _registered_client_indices.has(client_index):
		_fail("server received duplicate client index")
		return
	var sender_id := multiplayer.get_remote_sender_id()
	_registered_client_indices[client_index] = sender_id
	_sync_existing_roster_to(sender_id)
	NetworkManager._sync_peer.rpc(
		sender_id,
		CLIENT_STEAM_ID_BASE + client_index,
		"D5 Client %d" % client_index,
		false,
		client_index,
	)

func _sync_existing_roster_to(peer_id: int) -> void:
	for raw_peer_id in NetworkManager.peers.keys():
		var existing_peer_id := int(raw_peer_id)
		var data: Dictionary = NetworkManager.peers[raw_peer_id]
		NetworkManager._sync_peer.rpc_id(
			peer_id,
			existing_peer_id,
			int(data.get("steam_id", 0)),
			str(data.get("display_name", "")),
			bool(data.get("ready", false)),
			int(data.get("seat_id", -1)),
		)

func _process_server_roster(delta: float) -> void:
	if NetworkManager.peers.size() != EXPECTED_PLAYERS:
		_roster_ready_delay = -1.0
		return
	if _roster_ready_delay < 0.0:
		_roster_ready_delay = 0.25
		return
	_roster_ready_delay -= delta
	if _roster_ready_delay > 0.0:
		return
	_match_started = true
	if not MatchAuthority.begin_role_reveal():
		_fail("server could not begin role reveal")

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
		GameManager.MatchPhase.DAY_ANNOUNCEMENT,
	]:
		return
	MatchAuthority._clear_phase_timeout()
	MatchAuthority._handle_phase_timeout(phase)

func _on_private_role_received(role_value: int) -> void:
	if not _valid_role(role_value):
		_fail("received invalid private role")
		return
	_role_received = true
	call_deferred("_acknowledge_role")

func _acknowledge_role() -> void:
	MatchAuthority.acknowledge_local_role()

func _on_private_priest_warning_received(target_peer_id: int) -> void:
	_priest_warning_received = true
	_priest_warning_target = target_peer_id

func _on_phase_synced(phase_value: int) -> void:
	_visited_phases.append(phase_value)
	if _role == "server" and phase_value in [
		int(GameManager.MatchPhase.GOD_INTRO),
		int(GameManager.MatchPhase.NIGHT_START),
		int(GameManager.MatchPhase.HERETIC_ACTION),
		int(GameManager.MatchPhase.HEALER_ACTION),
		int(GameManager.MatchPhase.INQUISITOR_ACTION),
		int(GameManager.MatchPhase.DAY_ANNOUNCEMENT),
	]:
		_server_phase_advance_delay = FAST_FORWARD_DELAY_SECONDS
	if NightPhaseRules.is_action_phase(GameManager.phase):
		call_deferred("_try_submit_night_action")
	elif phase_value == int(GameManager.MatchPhase.DAY_DISCUSSION):
		call_deferred("_handle_day_discussion")

func _try_submit_night_action() -> void:
	if _action_sent or not _role_received:
		return
	var required_role := NightPhaseRules.role_for_phase(GameManager.phase)
	if required_role != MatchAuthority.local_role:
		return
	var target_peer_id := _choose_local_target(required_role)
	if target_peer_id <= 0:
		return
	_action_sent = true
	MatchAuthority.submit_local_night_target(target_peer_id)

func _choose_local_target(required_role: PlayerState.Role) -> int:
	var local_peer_id := multiplayer.get_unique_id()
	var peer_ids: Array[int] = []
	for raw_peer_id in NetworkManager.peers.keys():
		peer_ids.append(int(raw_peer_id))
	peer_ids.sort()
	if required_role == PlayerState.Role.HEALER:
		return local_peer_id
	for peer_id in peer_ids:
		if peer_id == local_peer_id:
			continue
		if required_role == PlayerState.Role.HERETIC:
			if peer_id == MatchAuthority.local_heretic_teammate_peer_id:
				continue
		return peer_id
	return 0

func _on_night_action_result_received(accepted: bool, _target_peer_id: int) -> void:
	if accepted:
		_action_accepted = true

func _on_private_investigation_received(target_peer_id: int, is_heretic: bool) -> void:
	_investigation_received = true
	_investigation_target = target_peer_id
	_investigation_is_heretic = is_heretic

func _handle_day_discussion() -> void:
	var validation_error := _local_day_validation_error()
	if not validation_error.is_empty():
		_fail(validation_error)
		return
	if _role == "server":
		_server_day_ready = true
		_try_complete_server()
	elif not _day_ack_sent:
		_day_ack_sent = true
		_ack_day_state.rpc_id(
			1,
			int(MatchAuthority.local_role),
			_dead_peer_count(),
			_action_accepted,
			MatchAuthority.local_heretic_teammate_peer_id,
			_priest_warning_received,
			_priest_warning_target,
			_investigation_received,
			_investigation_target,
			_investigation_is_heretic,
			_saw_full_night_sequence(),
		)

func _local_day_validation_error() -> String:
	var error := ""
	if GameManager.round_number != EXPECTED_ROUND:
		error = "day discussion round mismatch"
	elif NetworkManager.peers.size() != EXPECTED_PLAYERS:
		error = "roster changed during night"
	elif not _role_received:
		error = "day reached without private role"
	elif _dead_peer_count() != 0:
		error = "first night unexpectedly killed a player"
	elif MatchAuthority.local_role == PlayerState.Role.HERETIC:
		if MatchAuthority.local_heretic_teammate_peer_id <= 0:
			error = "heretic teammate was not delivered"
		elif _is_local_heretic_decider() and not _action_accepted:
			error = "first-night heretic decider action was not accepted"
		elif not _is_local_heretic_decider() and _action_accepted:
			error = "non-deciding heretic action was accepted"
	elif MatchAuthority.local_role == PlayerState.Role.HEALER:
		if not _priest_warning_received or _priest_warning_target <= 0:
			error = "priest did not receive first-night victim warning"
		elif _action_accepted:
			error = "priest manually acted during first night"
	elif MatchAuthority.local_role == PlayerState.Role.INQUISITOR:
		if _investigation_received:
			error = "inquisitor investigated during first night"
		elif _action_accepted:
			error = "inquisitor action was accepted during first night"
	if error.is_empty() and not _saw_full_night_sequence():
		error = "client missed part of the replicated first-night sequence"
	return error

func _is_local_heretic_decider() -> bool:
	return multiplayer.get_unique_id() == MatchAuthority.current_heretic_decider_peer_id

func _saw_full_night_sequence() -> bool:
	for required_phase in [
		GameManager.MatchPhase.NIGHT_START,
		GameManager.MatchPhase.HERETIC_ACTION,
		GameManager.MatchPhase.HEALER_ACTION,
		GameManager.MatchPhase.INQUISITOR_ACTION,
		GameManager.MatchPhase.NIGHT_RESOLUTION,
		GameManager.MatchPhase.DAY_ANNOUNCEMENT,
		GameManager.MatchPhase.DAY_DISCUSSION,
	]:
		if int(required_phase) not in _visited_phases:
			return false
	return true

func _dead_peer_count() -> int:
	var count := 0
	for raw_peer_id in NetworkManager.peers.keys():
		if not MatchAuthority.is_peer_publicly_alive(int(raw_peer_id)):
			count += 1
	return count

@rpc("any_peer", "call_remote", "reliable")
func _ack_day_state(
	role_value: int,
	dead_peer_count: int,
	action_accepted: bool,
	heretic_teammate_peer_id: int,
	priest_warning_received: bool,
	priest_warning_target: int,
	investigation_received: bool,
	investigation_target: int,
	investigation_is_heretic: bool,
	saw_full_night: bool,
) -> void:
	if _role != "server":
		return
	var sender_id := multiplayer.get_remote_sender_id()
	var validation_error := _client_day_ack_validation_error(
		sender_id,
		role_value,
		dead_peer_count,
		action_accepted,
		heretic_teammate_peer_id,
		priest_warning_received,
		priest_warning_target,
		investigation_received,
		investigation_target,
		investigation_is_heretic,
		saw_full_night,
	)
	if not validation_error.is_empty():
		_fail(validation_error)
		return
	if _validated_clients.has(sender_id):
		_fail("server received duplicate day acknowledgement")
		return
	_validated_clients[sender_id] = true
	_try_complete_server()

func _client_day_ack_validation_error(
	sender_id: int,
	role_value: int,
	dead_peer_count: int,
	action_accepted: bool,
	heretic_teammate_peer_id: int,
	priest_warning_received: bool,
	priest_warning_target: int,
	investigation_received: bool,
	investigation_target: int,
	investigation_is_heretic: bool,
	saw_full_night: bool,
) -> String:
	var expected_role := MatchAuthority.server_role_for_peer(sender_id)
	var error := ""
	if role_value != int(expected_role):
		error = "client role changed from authoritative role"
	elif dead_peer_count != _dead_peer_count():
		error = "client public death state diverged"
	elif expected_role == PlayerState.Role.HERETIC:
		error = _validate_heretic_ack(sender_id, heretic_teammate_peer_id, action_accepted)
	elif expected_role == PlayerState.Role.HEALER:
		error = _validate_priest_ack(
			priest_warning_received,
			priest_warning_target,
			action_accepted,
		)
	elif expected_role == PlayerState.Role.INQUISITOR:
		error = _validate_first_night_inquisitor_ack(
			investigation_received,
			investigation_target,
			investigation_is_heretic,
			action_accepted,
		)
	if error.is_empty() and not saw_full_night:
		error = "client did not observe full first-night phase sequence"
	return error

func _validate_heretic_ack(
	sender_id: int,
	teammate_peer_id: int,
	action_accepted: bool,
) -> String:
	var teammate = MatchAuthority._heretic_teammate_for(sender_id)
	if teammate == null or teammate_peer_id != teammate.peer_id:
		return "client heretic teammate did not match authoritative teammate"
	var should_act := sender_id == MatchAuthority.current_heretic_decider_peer_id
	if should_act and not action_accepted:
		return "first-night heretic decider action was not accepted"
	if not should_act and action_accepted:
		return "non-deciding heretic action was accepted"
	return ""

func _validate_priest_ack(
	warning_received: bool,
	warning_target: int,
	action_accepted: bool,
) -> String:
	if not warning_received:
		return "client priest did not receive first-night victim warning"
	var expected_target := int(MatchAuthority.get("_healer_target_peer_id"))
	if warning_target != expected_target or expected_target <= 0:
		return "client priest warning target did not match authoritative target"
	if action_accepted:
		return "client priest manually acted during first night"
	return ""

func _validate_first_night_inquisitor_ack(
	investigation_received: bool,
	investigation_target: int,
	investigation_is_heretic: bool,
	action_accepted: bool,
) -> String:
	if investigation_received or investigation_target != 0 or investigation_is_heretic:
		return "client inquisitor received a result during first night"
	if action_accepted:
		return "client inquisitor action was accepted during first night"
	return ""

func _server_day_validation_error() -> String:
	var heretic_targets: Dictionary = MatchAuthority.get("_heretic_targets")
	var healer_target := int(MatchAuthority.get("_healer_target_peer_id"))
	var inquisitor_target := int(MatchAuthority.get("_inquisitor_target_peer_id"))
	var error := ""
	if heretic_targets.size() != 1:
		error = "server did not preserve exactly one first-night heretic decision"
	elif healer_target <= 0:
		error = "server did not assign the first-night priest rescue target"
	elif inquisitor_target != 0:
		error = "server allowed an inquisitor target during first night"
	elif not MatchAuthority.last_night_was_first:
		error = "server did not mark the night as the first night"
	elif not MatchAuthority.last_night_killed_peer_ids.is_empty():
		error = "server killed a player during the protected first night"
	elif MatchAuthority.local_role == PlayerState.Role.HERETIC:
		if _is_local_heretic_decider() and not _action_accepted:
			error = "server heretic decider action was not accepted"
		elif not _is_local_heretic_decider() and _action_accepted:
			error = "server non-deciding heretic action was accepted"
	elif MatchAuthority.local_role == PlayerState.Role.HEALER:
		if not _priest_warning_received or _priest_warning_target != healer_target:
			error = "server priest did not receive the first-night victim warning"
		elif _action_accepted:
			error = "server priest manually acted during first night"
	elif MatchAuthority.local_role == PlayerState.Role.INQUISITOR:
		if _investigation_received or _action_accepted:
			error = "server inquisitor acted during first night"
	if error.is_empty() and not _public_alive_matches_session():
		error = "server public alive state diverged from authoritative session"
	return error

func _public_alive_matches_session() -> bool:
	var session: MatchSession = MatchAuthority.get("_session")
	if session == null:
		return false
	for player in session.players:
		if MatchAuthority.is_peer_publicly_alive(player.peer_id) != player.alive:
			return false
	return true

func _try_complete_server() -> void:
	if _completed or not _server_day_ready:
		return
	var validation_error := _server_day_validation_error()
	if not validation_error.is_empty():
		_fail(validation_error)
		return
	if _validated_clients.size() != EXPECTED_CLIENTS:
		return
	_completed = true
	_confirm_full_night.rpc()
	print("GREEN: Gate D5 server - exact-8 first-night ritual converged")
	_server_quit_delay = 0.25

func _valid_role(role_value: int) -> bool:
	return (
		role_value >= int(PlayerState.Role.FAITHFUL)
		and role_value <= int(PlayerState.Role.INQUISITOR)
	)

@rpc("authority", "call_remote", "reliable")
func _confirm_full_night() -> void:
	if _role != "client":
		return
	print("GREEN: Gate D5 client %d - first-night state matched" % _client_index)
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("RED: Gate D5 %s%s - %s" % [_role, _client_suffix(), message])
	get_tree().quit(1)
