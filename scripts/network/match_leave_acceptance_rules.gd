class_name MatchLeaveAcceptanceRules
extends RefCounted

enum ExitMode {
	REJECT,
	CLIENT_HANDSHAKE,
	HOST_MIGRATION,
}

static func exit_mode(
	lobby_id: int,
	is_host: bool,
	has_multiplayer_peer: bool,
	leave_pending: bool,
	match_started: bool,
) -> ExitMode:
	if not match_started:
		return ExitMode.REJECT
	if is_host:
		return (
			ExitMode.HOST_MIGRATION
			if MatchLeaveRules.can_request_host_leave(
				lobby_id,
				is_host,
				has_multiplayer_peer,
				leave_pending,
			)
			else ExitMode.REJECT
		)
	return (
		ExitMode.CLIENT_HANDSHAKE
		if MatchLeaveRules.can_request_non_host_leave(
			lobby_id,
			is_host,
			has_multiplayer_peer,
			leave_pending,
		)
		else ExitMode.REJECT
	)

static func host_transfer_failure_is_non_terminal(
	ownership_transferred: bool,
	original_host_connected: bool,
) -> bool:
	return not ownership_transferred and original_host_connected

static func successful_exit_contract(
	party_before: Dictionary,
	party_after: Dictionary,
	cleanup_state: Dictionary,
) -> bool:
	return (
		MatchLeavePartyInvariant.is_preserved(party_before, party_after)
		and MatchLeaveCleanupRules.is_clean(
			int(cleanup_state.get("lobby_id", -1)),
			int(cleanup_state.get("peer_count", -1)),
			int(cleanup_state.get("local_role", -1)),
			int(cleanup_state.get("public_alive_count", -1)),
			int(cleanup_state.get("backup_steam_id", -1)),
			int(cleanup_state.get("reconnect_count", -1)),
			StringName(cleanup_state.get("matchmaking_state", &"invalid")),
			int(cleanup_state.get("round_number", -1)),
			int(cleanup_state.get("phase", -1)),
		)
	)
