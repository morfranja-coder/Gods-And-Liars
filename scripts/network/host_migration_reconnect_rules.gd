class_name HostMigrationReconnectRules
extends RefCounted

const OLD_HOST_PEER_ID := 1

static func can_attempt_client_reconnect(
	lobby_id: int,
	local_steam_id: int,
	backup_steam_id: int,
	ready_owner_steam_id: int,
	has_active_peer: bool,
) -> bool:
	return (
		lobby_id > 0
		and local_steam_id > 0
		and backup_steam_id > 0
		and local_steam_id != backup_steam_id
		and ready_owner_steam_id == backup_steam_id
		and not has_active_peer
	)

static func old_peer_id_for_steam_id(snapshot: MatchSnapshot, steam_id: int) -> int:
	if snapshot == null or steam_id <= 0:
		return 0
	for data in snapshot.players:
		if int(data.get("steam_id", 0)) == steam_id:
			return int(data.get("peer_id", 0))
	return 0

static func expected_remaining_players(snapshot: MatchSnapshot) -> int:
	return 0 if snapshot == null else maxi(0, snapshot.players.size() - 1)
