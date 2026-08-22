class_name MatchLeaveCleanupRules
extends RefCounted

static func is_clean(
	lobby_id: int,
	peer_count: int,
	local_role: int,
	public_alive_count: int,
	backup_steam_id: int,
	reconnect_mapping_count: int,
	matchmaking_state: StringName,
	round_number: int,
	phase: int,
) -> bool:
	return (
		lobby_id == 0
		and peer_count == 0
		and local_role == int(PlayerState.Role.UNASSIGNED)
		and public_alive_count == 0
		and backup_steam_id == 0
		and reconnect_mapping_count == 0
		and matchmaking_state == MatchmakingManager.STATE_IDLE
		and round_number == 0
		and phase == int(GameManager.MatchPhase.LOBBY)
	)