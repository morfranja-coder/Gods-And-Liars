class_name BackupAuthorityRules
extends RefCounted

static func keep_or_choose_backup(
	roster: Dictionary,
	alive_by_peer: Dictionary,
	current_host_steam_id: int,
	current_backup_steam_id: int,
) -> int:
	if _steam_id_is_connected(roster, current_backup_steam_id, current_host_steam_id):
		return current_backup_steam_id
	return HostSuccessorRules.choose_successor_steam_id(
		roster,
		alive_by_peer,
		current_host_steam_id,
	)

static func peer_id_for_steam_id(roster: Dictionary, steam_id: int) -> int:
	if steam_id <= 0:
		return 0
	for raw_peer_id in roster.keys():
		var data: Dictionary = roster[raw_peer_id]
		if int(data.get("steam_id", 0)) == steam_id:
			return int(raw_peer_id)
	return 0

static func _steam_id_is_connected(
	roster: Dictionary,
	steam_id: int,
	current_host_steam_id: int,
) -> bool:
	return (
		steam_id > 0
		and steam_id != current_host_steam_id
		and peer_id_for_steam_id(roster, steam_id) > 0
	)
