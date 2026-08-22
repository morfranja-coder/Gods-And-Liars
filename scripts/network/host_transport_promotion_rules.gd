class_name HostTransportPromotionRules
extends RefCounted

static func can_promote(
	lobby_id: int,
	local_steam_id: int,
	backup_steam_id: int,
	observed_owner_steam_id: int,
	has_valid_snapshot: bool,
	has_active_multiplayer_peer: bool,
) -> bool:
	return (
		lobby_id > 0
		and local_steam_id > 0
		and local_steam_id == backup_steam_id
		and observed_owner_steam_id == backup_steam_id
		and has_valid_snapshot
		and not has_active_multiplayer_peer
	)
