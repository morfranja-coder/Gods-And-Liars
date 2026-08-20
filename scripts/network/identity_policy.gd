class_name IdentityPolicy
extends RefCounted

const MAX_DISPLAY_NAME_LENGTH := 64

static func valid_steam_id(steam_id: int) -> bool:
	return steam_id > 0

static func sanitize_display_name(display_name: String) -> String:
	var clean := display_name.strip_edges()
	if clean.length() > MAX_DISPLAY_NAME_LENGTH:
		clean = clean.left(MAX_DISPLAY_NAME_LENGTH)
	return clean

static func valid_display_name(display_name: String) -> bool:
	var clean := sanitize_display_name(display_name)
	return not clean.is_empty()

static func valid_identity(steam_id: int, display_name: String) -> bool:
	return valid_steam_id(steam_id) and valid_display_name(display_name)

static func steam_id_in_use(peers: Dictionary, steam_id: int, except_peer_id: int = 0) -> bool:
	for peer_id in peers.keys():
		if int(peer_id) == except_peer_id:
			continue
		var data: Dictionary = peers[peer_id]
		if int(data.get("steam_id", 0)) == steam_id:
			return true
	return false
