class_name QALocalTransportProbe
extends Node

signal completed(success: bool, message: String)

const EXPECTED_PHASE := 9
const EXPECTED_ROUND := 3
const EXPECTED_ROSTER_SIZE := 8

var _is_server := false

func start_server(port: int) -> Error:
	_is_server = true
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, 2)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	return OK

func start_client(host: String, port: int) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(host, port)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	return OK

func _on_peer_connected(peer_id: int) -> void:
	if not _is_server:
		return
	_receive_authoritative_snapshot.rpc_id(
		peer_id,
		EXPECTED_PHASE,
		EXPECTED_ROUND,
		EXPECTED_ROSTER_SIZE,
	)

func _on_connected_to_server() -> void:
	print("D1 CLIENT: connected to local host")

func _on_connection_failed() -> void:
	completed.emit(false, "client connection failed")

@rpc("authority", "call_remote", "reliable")
func _receive_authoritative_snapshot(phase_value: int, round_value: int, roster_size: int) -> void:
	if phase_value != EXPECTED_PHASE:
		completed.emit(false, "phase mismatch")
		return
	if round_value != EXPECTED_ROUND:
		completed.emit(false, "round mismatch")
		return
	if roster_size != EXPECTED_ROSTER_SIZE:
		completed.emit(false, "roster size mismatch")
		return
	_ack_snapshot.rpc_id(1, phase_value, round_value, roster_size)
	completed.emit(true, "client received authoritative snapshot")

@rpc("any_peer", "call_remote", "reliable")
func _ack_snapshot(phase_value: int, round_value: int, roster_size: int) -> void:
	if not _is_server:
		return
	if phase_value != EXPECTED_PHASE or round_value != EXPECTED_ROUND:
		completed.emit(false, "server received invalid acknowledgement")
		return
	if roster_size != EXPECTED_ROSTER_SIZE:
		completed.emit(false, "server received invalid roster acknowledgement")
		return
	completed.emit(true, "server received matching acknowledgement")
