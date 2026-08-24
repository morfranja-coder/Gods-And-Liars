extends Node

const PORT := 24682
const TIMEOUT_SECONDS := 12.0
const HOST_STEAM_ID := 910001
const CLIENT_STEAM_ID := 910002
const EXPECTED_ROUND := 2

var _role := ""
var _elapsed := 0.0
var _sequence_sent := false
var _server_quit_delay := -1.0
var _visited_phases: Array[int] = []

func _ready() -> void:
	_role = _parse_role()
	if _role not in ["server", "client"]:
		_fail("missing or invalid role argument")
		return

	NetworkManager.reset()
	MatchAuthority.reset()
	GameManager.reset_match()
	Steamworks.steam_id = HOST_STEAM_ID if _role == "server" else CLIENT_STEAM_ID
	Steamworks.persona_name = "D2 Host" if _role == "server" else "D2 Client"
	MatchAuthority.phase_synced.connect(_on_phase_synced)
	MatchAuthority.match_end_received.connect(_on_match_end_received)

	var peer := ENetMultiplayerPeer.new()
	var error := OK
	if _role == "server":
		NetworkManager.is_host = true
		NetworkManager.set("_reserved_party_steam_ids", [CLIENT_STEAM_ID])
		NetworkManager.register_peer(1, HOST_STEAM_ID, "D2 Host", 0)
		error = peer.create_server(PORT, 2)
	else:
		error = peer.create_client("127.0.0.1", PORT)
	if error != OK:
		_fail("failed to create %s peer: %s" % [_role, error_string(error)])
		return

	multiplayer.multiplayer_peer = peer
	print("D2 %s: transport started" % _role.to_upper())

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= TIMEOUT_SECONDS:
		_fail("%s timed out" % _role)
		return

	if _role == "server" and not _sequence_sent and NetworkManager.peers.size() == 2:
		_sequence_sent = true
		_send_runtime_sequence()

	if _server_quit_delay >= 0.0:
		_server_quit_delay -= delta
		if _server_quit_delay <= 0.0:
			get_tree().quit(0)

func _parse_role() -> String:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		return ""
	return str(args[0]).strip_edges().to_lower()

func _send_runtime_sequence() -> void:
	MatchAuthority._sync_phase.rpc(int(GameManager.MatchPhase.ROLE_REVEAL), EXPECTED_ROUND)
	MatchAuthority._sync_phase.rpc(int(GameManager.MatchPhase.NIGHT_RESOLUTION), EXPECTED_ROUND)
	var killed_peer_ids: Array[int] = [2]
	MatchAuthority._sync_night_resolution.rpc(killed_peer_ids)
	MatchAuthority._sync_phase.rpc(int(GameManager.MatchPhase.DAY_DISCUSSION), EXPECTED_ROUND)
	MatchAuthority._sync_phase.rpc(int(GameManager.MatchPhase.SACRIFICE), EXPECTED_ROUND)
	MatchAuthority._sync_sacrifice.rpc(0, true)
	MatchAuthority._sync_match_end.rpc("faithful")

func _on_phase_synced(phase_value: int) -> void:
	_visited_phases.append(phase_value)

func _on_match_end_received(_winner: StringName) -> void:
	if _role != "client":
		return
	if int(GameManager.phase) != int(GameManager.MatchPhase.MATCH_END):
		_fail("client did not reach MATCH_END")
		return
	if GameManager.round_number != EXPECTED_ROUND:
		_fail("client round mismatch")
		return
	if MatchAuthority.public_winner != &"faithful":
		_fail("client winner mismatch")
		return
	if MatchAuthority.is_peer_publicly_alive(2):
		_fail("client did not replicate public death")
		return
	if NetworkManager.peers.size() != 2:
		_fail("client roster did not converge to two peers")
		return
	for required_phase in [
		GameManager.MatchPhase.ROLE_REVEAL,
		GameManager.MatchPhase.NIGHT_RESOLUTION,
		GameManager.MatchPhase.DAY_DISCUSSION,
		GameManager.MatchPhase.SACRIFICE,
	]:
		if int(required_phase) not in _visited_phases:
			_fail("client missed replicated phase %s" % required_phase)
			return
	_ack_runtime_state.rpc_id(
		1,
		int(GameManager.phase),
		GameManager.round_number,
		str(MatchAuthority.public_winner),
		NetworkManager.peers.size(),
		not MatchAuthority.is_peer_publicly_alive(2),
	)

@rpc("any_peer", "call_remote", "reliable")
func _ack_runtime_state(
	phase_value: int,
	round_value: int,
	winner_value: String,
	roster_size: int,
	peer_two_dead: bool,
) -> void:
	if _role != "server":
		return
	if phase_value != int(GameManager.MatchPhase.MATCH_END):
		_fail("server received phase mismatch")
		return
	if round_value != EXPECTED_ROUND or winner_value != "faithful":
		_fail("server received runtime mismatch")
		return
	if roster_size != 2 or not peer_two_dead:
		_fail("server received roster/death mismatch")
		return
	var sender_id := multiplayer.get_remote_sender_id()
	_confirm_runtime_state.rpc_id(sender_id)
	print("GREEN: Gate D2 server - runtime state matched client")
	_server_quit_delay = 0.25

@rpc("authority", "call_remote", "reliable")
func _confirm_runtime_state() -> void:
	if _role != "client":
		return
	print("GREEN: Gate D2 client - runtime state matched server")
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("RED: Gate D2 %s - %s" % [_role, message])
	get_tree().quit(1)
