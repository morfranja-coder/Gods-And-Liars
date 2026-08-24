extends Node

const PORT := 24684
const TIMEOUT_SECONDS := 15.0
const HOST_STEAM_ID := 930000
const CLIENT_STEAM_ID_BASE := 930000
const EXPECTED_PLAYERS := 8
const EXPECTED_CLIENTS := 7
const EXPECTED_ROUND := 1

var _role := ""
var _client_index := 0
var _elapsed := 0.0
var _roster_ready_delay := -1.0
var _match_started := false
var _role_received := false
var _first_night_ack_sent := false
var _server_first_night_ready := false
var _completed := false
var _server_quit_delay := -1.0
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
	MatchAuthority.phase_synced.connect(_on_phase_synced)

	var peer := ENetMultiplayerPeer.new()
	var error := OK
	if _role == "server":
		NetworkManager.is_host = true
		NetworkManager.register_peer(1, HOST_STEAM_ID, "D4 Host", 0)
		error = peer.create_server(PORT, EXPECTED_PLAYERS)
	else:
		_disconnect_steam_identity_handshake()
		multiplayer.connected_to_server.connect(_on_connected_to_server)
		error = peer.create_client("127.0.0.1", PORT)
	if error != OK:
		_fail("failed to create %s peer: %s" % [_role, error_string(error)])
		return

	multiplayer.multiplayer_peer = peer
	print("D4 %s%s: transport started" % [_role.to_upper(), _client_suffix()])

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= TIMEOUT_SECONDS:
		_fail("%s timed out" % _role)
		return

	if _role == "server" and not _match_started:
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
	return "D4 Host" if _role == "server" else "D4 Client %d" % _client_index

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
		"D4 Client %d" % client_index,
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
	if _seat_signature() != "0,1,2,3,4,5,6,7":
		_fail("server seat assignment mismatch before role reveal")
		return
	if not MatchAuthority.begin_role_reveal():
		_fail("server could not begin role reveal")

func _on_private_role_received(role_value: int) -> void:
	if not _valid_role(role_value):
		_fail("received invalid private role")
		return
	_role_received = true
	call_deferred("_acknowledge_role")

func _acknowledge_role() -> void:
	MatchAuthority.acknowledge_local_role()

func _on_phase_synced(phase_value: int) -> void:
	if phase_value != int(GameManager.MatchPhase.HERETIC_ACTION):
		return
	if not _role_received:
		_fail("reached first night action without private role")
		return
	if GameManager.round_number != EXPECTED_ROUND:
		_fail("first night round mismatch")
		return
	if _role == "server":
		_server_first_night_ready = true
		var validation_error := _server_runtime_validation_error()
		if not validation_error.is_empty():
			_fail(validation_error)
			return
		_try_complete_server()
	elif not _first_night_ack_sent:
		_first_night_ack_sent = true
		_ack_role_state.rpc_id(
			1,
			int(MatchAuthority.local_role),
			GameManager.round_number,
			NetworkManager.peers.size(),
			_seat_signature(),
		)

func _server_runtime_validation_error() -> String:
	var error := ""
	var acknowledged: Dictionary = MatchAuthority.get("_role_acknowledged")
	if NetworkManager.peers.size() != EXPECTED_PLAYERS:
		error = "server roster changed before first night action"
	elif acknowledged.size() != EXPECTED_PLAYERS:
		error = "server did not receive all eight role acknowledgements"
	elif _seat_signature() != "0,1,2,3,4,5,6,7":
		error = "server seat assignment changed"
	elif not _server_role_distribution_valid():
		error = "server authoritative role distribution mismatch"
	return error

func _server_role_distribution_valid() -> bool:
	var counts := {
		PlayerState.Role.FAITHFUL: 0,
		PlayerState.Role.HERETIC: 0,
		PlayerState.Role.HEALER: 0,
		PlayerState.Role.INQUISITOR: 0,
	}
	for raw_peer_id in NetworkManager.peers.keys():
		var peer_id := int(raw_peer_id)
		var role_value := MatchAuthority.server_role_for_peer(peer_id)
		if role_value == PlayerState.Role.UNASSIGNED:
			return false
		counts[role_value] = int(counts.get(role_value, 0)) + 1
	return (
		int(counts[PlayerState.Role.FAITHFUL]) == 4
		and int(counts[PlayerState.Role.HERETIC]) == 2
		and int(counts[PlayerState.Role.HEALER]) == 1
		and int(counts[PlayerState.Role.INQUISITOR]) == 1
	)

@rpc("any_peer", "call_remote", "reliable")
func _ack_role_state(
	role_value: int,
	round_value: int,
	roster_size: int,
	seat_signature: String,
) -> void:
	if _role != "server":
		return
	var sender_id := multiplayer.get_remote_sender_id()
	var validation_error := _client_ack_validation_error(
		sender_id,
		role_value,
		round_value,
		roster_size,
		seat_signature,
	)
	if not validation_error.is_empty():
		_fail(validation_error)
		return
	if _validated_clients.has(sender_id):
		_fail("server received duplicate first-night acknowledgement")
		return
	_validated_clients[sender_id] = true
	_try_complete_server()

func _client_ack_validation_error(
	sender_id: int,
	role_value: int,
	round_value: int,
	roster_size: int,
	seat_signature: String,
) -> String:
	var error := ""
	var expected_role := MatchAuthority.server_role_for_peer(sender_id)
	if not _valid_role(role_value):
		error = "server received invalid client role"
	elif role_value != int(expected_role):
		error = "client private role did not match authoritative role"
	elif round_value != EXPECTED_ROUND:
		error = "server received client round mismatch"
	elif roster_size != EXPECTED_PLAYERS:
		error = "server received client roster mismatch"
	elif seat_signature != "0,1,2,3,4,5,6,7":
		error = "server received client seat mismatch"
	return error

func _try_complete_server() -> void:
	if _completed or not _server_first_night_ready:
		return
	if _validated_clients.size() != EXPECTED_CLIENTS:
		return
	_completed = true
	_confirm_role_reveal.rpc()
	print("GREEN: Gate D4 server - exact-8 private roles and ACKs matched")
	_server_quit_delay = 0.25

func _valid_role(role_value: int) -> bool:
	return (
		role_value >= int(PlayerState.Role.FAITHFUL)
		and role_value <= int(PlayerState.Role.INQUISITOR)
	)

func _seat_signature() -> String:
	var seats: Array[int] = []
	for data in NetworkManager.peers.values():
		seats.append(int(data.get("seat_id", -1)))
	seats.sort()
	var parts := PackedStringArray()
	for seat_id in seats:
		parts.append(str(seat_id))
	return ",".join(parts)

@rpc("authority", "call_remote", "reliable")
func _confirm_role_reveal() -> void:
	if _role != "client":
		return
	print("GREEN: Gate D4 client %d - private role and ACK matched" % _client_index)
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("RED: Gate D4 %s%s - %s" % [_role, _client_suffix(), message])
	get_tree().quit(1)
