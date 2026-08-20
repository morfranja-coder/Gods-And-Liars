extends Node

signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal lobby_state_changed(state: StringName)

var is_host: bool = false
var lobby_id: int = 0
var peers: Dictionary = {}

func reset() -> void:
	is_host = false
	lobby_id = 0
	peers.clear()
	lobby_state_changed.emit(&"offline")

func register_peer(peer_id: int, steam_id: int = 0, display_name: String = "") -> void:
	peers[peer_id] = {
		"steam_id": steam_id,
		"display_name": display_name,
		"seat_id": -1,
		"ready": false,
	}
	peer_joined.emit(peer_id)

func unregister_peer(peer_id: int) -> void:
	if not peers.has(peer_id):
		return
	peers.erase(peer_id)
	peer_left.emit(peer_id)

func set_peer_ready(peer_id: int, ready: bool) -> void:
	if peers.has(peer_id):
		peers[peer_id]["ready"] = ready

func all_peers_ready() -> bool:
	if peers.is_empty():
		return false
	for peer: Dictionary in peers.values():
		if not peer.get("ready", false):
			return false
	return true
