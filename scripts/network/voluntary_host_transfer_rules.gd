class_name VoluntaryHostTransferRules
extends RefCounted

static func can_transfer(
	lobby_id: int,
	current_host_steam_id: int,
	backup_steam_id: int,
	backup_peer_id: int,
	roster: Dictionary,
	has_backup_snapshot: bool,
) -> bool:
	if lobby_id <= 0 or current_host_steam_id <= 0:
		return false
	if backup_steam_id <= 0 or backup_steam_id == current_host_steam_id:
		return false
	if backup_peer_id <= 0 or not roster.has(backup_peer_id):
		return false
	var backup_data: Dictionary = roster[backup_peer_id]
	if int(backup_data.get("steam_id", 0)) != backup_steam_id:
		return false
	return has_backup_snapshot
