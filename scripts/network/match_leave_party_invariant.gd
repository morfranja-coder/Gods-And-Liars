class_name MatchLeavePartyInvariant
extends RefCounted

static func capture(
	party_lobby_id: int,
	match_target_lobby_id: int,
	party_id: int,
	leader_steam_id: int,
	members: Dictionary,
) -> Dictionary:
	return {
		"party_lobby_id": party_lobby_id,
		"match_target_lobby_id": match_target_lobby_id,
		"party_id": party_id,
		"leader_steam_id": leader_steam_id,
		"members": members.duplicate(true),
	}

static func is_preserved(before: Dictionary, after: Dictionary) -> bool:
	if before.is_empty() or after.is_empty():
		return false
	return (
		int(before.get("party_lobby_id", 0)) == int(after.get("party_lobby_id", 0))
		and int(before.get("match_target_lobby_id", 0))
		== int(after.get("match_target_lobby_id", 0))
		and int(before.get("party_id", 0)) == int(after.get("party_id", 0))
		and int(before.get("leader_steam_id", 0)) == int(after.get("leader_steam_id", 0))
		and before.get("members", {}) == after.get("members", {})
	)
