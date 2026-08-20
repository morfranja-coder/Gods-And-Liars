class_name LobbyRules
extends RefCounted

const TECHNICAL_START_MIN_PLAYERS := 2

static func all_ready(peers: Dictionary, min_players: int = TECHNICAL_START_MIN_PLAYERS) -> bool:
	if peers.size() < min_players:
		return false
	for peer: Dictionary in peers.values():
		if not bool(peer.get("ready", false)):
			return false
	return true

static func can_start(is_host: bool, is_server: bool, peers: Dictionary, min_players: int = TECHNICAL_START_MIN_PLAYERS) -> bool:
	return is_host and is_server and all_ready(peers, min_players)

static func can_register_peer(peers: Dictionary, peer_id: int, max_players: int) -> bool:
	if peer_id <= 0 or max_players <= 0:
		return false
	if peers.has(peer_id):
		return true
	return peers.size() < max_players

static func make_peer(steam_id: int, display_name: String, ready: bool = false, seat_id: int = -1) -> Dictionary:
	return {
		"steam_id": steam_id,
		"display_name": display_name,
		"seat_id": seat_id,
		"ready": ready,
	}
