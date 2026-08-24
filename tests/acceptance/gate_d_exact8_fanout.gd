extends Node

const PORT := 24683
const TIMEOUT_SECONDS := 15.0
const HOST_STEAM_ID := 920000
const CLIENT_STEAM_ID_BASE := 920000
const EXPECTED_ROUND := 2
const EXPECTED_PLAYERS := 8
const EXPECTED_CLIENTS := 7

var _role := ""
var _client_index := 0
var _elapsed := 0.0
var _sequence_sent := false
var _roster_ready_delay := -1.0
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
	MatchAuthority.phase_synced.connect(_on_phase_synced)
	MatchAuthority.match_end_received.connect(_on_match_end_received)

	var peer := ENetMultiplayerPeer.new()
	var error := OK
	if _role == "server":
		NetworkManager.is_host = true
		NetworkManager.register_peer(1, HOST_STEAM_ID, "D3 Host", 0)
		error = peer.create_server(PORT, EXPECTED_PLAYERS)
	else:
		_disconnect_steam_identity_handshake()
		multiplayer.connected_to_server.connect(_on_connected_to_server)
		error = peer.create_client("127.0.0.1", PORT)
	if error != OK:
		_fail("failed to create %s peer: %s" % [_role, error_string(error)])
		return

	multiplayer.multiplayer_peer = peer
	print("D3 %s%s: transport started" % [_role.to_upper(), _client_suffix()])

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= TIMEOUT_SECONDS:
		_fail("%s timed out" % _role)
		return

	if _role == "server" and not _sequence_sent:
		_process_server_roster(delta)

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
	return "D3 Host" if _role == "server" else "D3 Client %d" % _client_index

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
		"D3 Client %d" % client_index,
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
	if _roster_ready_delay <= 0.0:
		_sequence_sent = true
		_send_runtime_sequence()

func _send_runtime_sequence() -> void:
	MatchAuthority._sync_phase.rpc(int(GameManager.MatchPhase.ROLE_REVEAL), EXPECTED_ROUND)
	MatchAuthority._sync_phase.rpc(int(GameManager.MatchPhase.NIGHT_RESOLUTION), EXPECTED_ROUND)
	var killed_peer_ids: Array[int] = [_selected_killed_peer_id()]
	MatchAuthority._sync_night_resolution.rpc(killed_peer_ids)
	MatchAuthority._sync_phase.rpc(int(GameManager.MatchPhase.DAY_DISCUSSION), EXPECTED_ROUND)
	MatchAuthority._sync_phase.rpc(int(GameManager.MatchPhase.SACRIFICE), EXPECTED_ROUND)
	MatchAuthority._sync_sacrifice.rpc(0, true)
	MatchAuthority._sync_match_end.rpc("faithful")

func _selected_killed_peer_id() -> int:
	var peer_ids: Array[int] = []
	for raw_peer_id in NetworkManager.peers.keys():
		peer_ids.append(int(raw_peer_id))
	peer_ids.sort()
	return peer_ids[-1]

func _on_phase_synced(phase_value: int) -> void:
	_visited_phases.append(phase_value)

func _on_match_end_received(_winner: StringName) -> void:
	if _role != "client":
		return
	var validation_error := _client_runtime_validation_error()
	if not validation_error.is_empty():
		_fail(validation_error)
		return
	_ack_runtime_state.rpc_id(
		1,
		int(GameManager.phase),
		GameManager.round_number,
		str(MatchAuthority.public_winner),
		NetworkManager.peers.size(),
		_dead_peer_count(),
		_seat_signature(),
	)

func _client_runtime_validation_error() -> String:
	var error := ""
	if int(GameManager.phase) != int(GameManager.MatchPhase.MATCH_END):
		error = "client did not reach MATCH_END"
	elif GameManager.round_number != EXPECTED_ROUND:
		error = "client round mismatch"
	elif MatchAuthority.public_winner != &"faithful":
		error = "client winner mismatch"
	elif NetworkManager.peers.size() != EXPECTED_PLAYERS:
		error = "client roster did not converge to exact 8"
	elif _seat_signature() != "0,1,2,3,4,5,6,7":
		error = "client seat assignment mismatch"
	elif _dead_peer_count() != 1:
		error = "client public death state mismatch"
	else:
		error = _missing_phase_error()
	return error

func _missing_phase_error() -> String:
	for required_phase in [
		GameManager.MatchPhase.ROLE_REVEAL,
		GameManager.MatchPhase.NIGHT_RESOLUTION,
		GameManager.MatchPhase.DAY_DISCUSSION,
		GameManager.MatchPhase.SACRIFICE,
	]:
		if int(required_phase) not in _visited_phases:
			return "client missed replicated phase %s" % required_phase
	return ""

func _dead_peer_count() -> int:
	var count := 0
	for raw_peer_id in NetworkManager.peers.keys():
		if not MatchAuthority.is_peer_publicly_alive(int(raw_peer_id)):
			count += 1
	return count

func _seat_signature() -> String:
	var seats: Array[int] = []
	for data in NetworkManager.peers.values():
		seats.append(int(data.get("seat_id", -1)))
	seats.sort()
	var parts := PackedStringArray()
	for seat_id in seats:
		parts.append(str(seat_id))
	return ",".join(parts)

@rpc("any_peer", "call_remote", "reliable")
func _ack_runtime_state(
	phase_value: int,
	round_value: int,
	winner_value: String,
	roster_size: int,
	dead_peer_count: int,
	seat_signature: String,
) -> void:
	if _role != "server":
		return
	var validation_error := _server_ack_validation_error(
		phase_value,
		round_value,
		winner_value,
		roster_size,
		dead_peer_count,
		seat_signature,
	)
	if not validation_error.is_empty():
		_fail(validation_error)
		return
	var sender_id := multiplayer.get_remote_sender_id()
	_validated_clients[sender_id] = true
	if _validated_clients.size() == EXPECTED_CLIENTS:
		_confirm_runtime_state.rpc()
		print("GREEN: Gate D3 server - all 7 clients matched exact-8 runtime")
		_server_quit_delay = 0.25

func _server_ack_validation_error(
	phase_value: int,
	round_value: int,
	winner_value: String,
	roster_size: int,
	dead_peer_count: int,
	seat_signature: String,
) -> String:
	var error := ""
	if phase_value != int(GameManager.MatchPhase.MATCH_END):
		error = "server received phase mismatch"
	elif round_value != EXPECTED_ROUND or winner_value != "faithful":
		error = "server received runtime mismatch"
	elif roster_size != EXPECTED_PLAYERS or dead_peer_count != 1:
		error = "server received roster/death mismatch"
	elif seat_signature != "0,1,2,3,4,5,6,7":
		error = "server received seat mismatch"
	return error

@rpc("authority", "call_remote", "reliable")
func _confirm_runtime_state() -> void:
	if _role != "client":
		return
	print("GREEN: Gate D3 client %d - exact-8 runtime matched" % _client_index)
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("RED: Gate D3 %s%s - %s" % [_role, _client_suffix(), message])
	get_tree().quit(1)
