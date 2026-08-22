class_name HostLossRecoveryRules
extends RefCounted

enum RecoveryRole {
	NONE,
	BACKUP,
	TEMPORARY_OWNER,
	OBSERVER,
}

static func role_for(
	local_steam_id: int,
	backup_steam_id: int,
	observed_owner_steam_id: int,
	has_valid_backup_snapshot: bool,
) -> RecoveryRole:
	if local_steam_id <= 0 or backup_steam_id <= 0:
		return RecoveryRole.NONE
	if local_steam_id == backup_steam_id:
		return RecoveryRole.BACKUP if has_valid_backup_snapshot else RecoveryRole.NONE
	if observed_owner_steam_id == local_steam_id:
		return RecoveryRole.TEMPORARY_OWNER
	return RecoveryRole.OBSERVER

static func owner_confirms_backup(
	observed_owner_steam_id: int,
	backup_steam_id: int,
) -> bool:
	return backup_steam_id > 0 and observed_owner_steam_id == backup_steam_id

static func should_handoff_temporary_owner(
	local_steam_id: int,
	backup_steam_id: int,
	observed_owner_steam_id: int,
) -> bool:
	return (
		local_steam_id > 0
		and backup_steam_id > 0
		and local_steam_id != backup_steam_id
		and observed_owner_steam_id == local_steam_id
	)
