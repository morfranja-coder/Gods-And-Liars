class_name HostSuccessorRules
extends RefCounted

static func choose_successor_steam_id(
	roster: Dictionary,
	alive_by_peer: Dictionary,
	current_host_steam_id: int,
) -> int:
	var alive_candidates: Array[int] = []
	var fallback_candidates: Array[int] = []
	for raw_peer_id in roster.keys():
		var peer_id := int(raw_peer_id)
		var data: Dictionary = roster[raw_peer_id]
		var steam_id := int(data.get("steam_id", 0))
		if steam_id <= 0 or steam_id == current_host_steam_id:
			continue
		fallback_candidates.append(steam_id)
		if bool(alive_by_peer.get(peer_id, true)):
			alive_candidates.append(steam_id)
	return _lowest_steam_id(alive_candidates if not alive_candidates.is_empty() else fallback_candidates)

static func _lowest_steam_id(candidates: Array[int]) -> int:
	if candidates.is_empty():
		return 0
	candidates.sort()
	return candidates[0]
