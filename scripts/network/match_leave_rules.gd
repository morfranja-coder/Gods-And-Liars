class_name MatchLeaveRules
extends RefCounted

static func can_request_non_host_leave(
	lobby_id: int,
	is_host: bool,
	has_multiplayer_peer: bool,
	leave_pending: bool,
) -> bool:
	return (
		lobby_id > 0
		and not is_host
		and has_multiplayer_peer
		and not leave_pending
	)

static func server_accepts_leave(
	sender_peer_id: int,
	claimed_steam_id: int,
	roster: Dictionary,
) -> bool:
	if sender_peer_id <= 1 or claimed_steam_id <= 0 or not roster.has(sender_peer_id):
		return false
	var peer: Dictionary = roster[sender_peer_id]
	return int(peer.get("steam_id", 0)) == claimed_steam_id
