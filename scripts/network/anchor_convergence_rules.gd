class_name AnchorConvergenceRules
extends RefCounted

static func is_pure_anchor(party_size: int, open_slots: int) -> bool:
	if not QuickMatchRules.valid_party_size(party_size):
		return false
	return open_slots == QuickMatchRules.TARGET_PLAYERS - party_size

static func can_merge(local_party_size: int, remote_party_size: int, remote_open_slots: int) -> bool:
	if not QuickMatchRules.valid_party_size(local_party_size):
		return false
	if not is_pure_anchor(remote_party_size, remote_open_slots):
		return false
	return local_party_size + remote_party_size <= QuickMatchRules.TARGET_PLAYERS

static func should_migrate(
	local_lobby_id: int,
	local_party_size: int,
	remote_lobby_id: int,
	remote_party_size: int,
	remote_open_slots: int,
) -> bool:
	if local_lobby_id <= 0 or remote_lobby_id <= 0 or local_lobby_id == remote_lobby_id:
		return false
	if remote_lobby_id >= local_lobby_id:
		return false
	return can_merge(local_party_size, remote_party_size, remote_open_slots)
