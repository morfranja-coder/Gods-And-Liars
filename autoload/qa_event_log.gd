extends Node

const ENV_QA_LOG := "GODS_LIARS_QA_LOG"
const ENV_QA_CLIENT := "GODS_LIARS_QA_CLIENT"
const DEFAULT_LOG_PATH := "user://qa-session.log"

var enabled: bool = false
var client_label: String = ""
var _file: FileAccess = null
var _last_party_members: Dictionary = {}
var _party_lobby_transition: StringName = &""

func _ready() -> void:
	enabled = OS.get_environment(ENV_QA_LOG) == "1"
	if not enabled:
		return
	client_label = QAEventLogRules.sanitize_client_label(OS.get_environment(ENV_QA_CLIENT))
	var log_path := DEFAULT_LOG_PATH
	if not client_label.is_empty():
		log_path = "user://qa-session-%s.log" % client_label
	_file = FileAccess.open(log_path, FileAccess.WRITE)
	if _file == null:
		push_warning("QAEventLog could not open %s" % log_path)
		enabled = false
		return
	_connect_signals()
	_write_event("qa_log_started", {"log_path": log_path})
	_log_initial_state()

func _exit_tree() -> void:
	if _file != null:
		_write_event("qa_log_stopped")
		_file.flush()
		_file.close()

func snapshot(label: String) -> void:
	if not enabled:
		return
	var peer_id := _local_peer_id()
	var seat_id := -1
	if NetworkManager.peers.has(peer_id):
		seat_id = int(NetworkManager.peers[peer_id].get("seat_id", -1))
	var alive := true
	if peer_id > 0 and MatchAuthority.public_alive_by_peer.has(peer_id):
		alive = MatchAuthority.is_peer_publicly_alive(peer_id)
	_write_event(
		"snapshot",
		{
			"label": label,
			"seat_id": seat_id,
			"local_role": int(MatchAuthority.local_role),
			"alive": alive,
			"winner": str(MatchAuthority.public_winner),
		},
	)

func _connect_signals() -> void:
	Steamworks.steam_ready.connect(_on_steam_ready)
	Steamworks.steam_unavailable.connect(_on_steam_unavailable)
	PartyManager.party_changed.connect(_on_party_changed)
	PartyManager.party_lobby_state_changed.connect(_on_party_lobby_state_changed)
	PartyManager.match_target_changed.connect(_on_match_target_changed)
	MatchmakingManager.queue_state_changed.connect(_on_queue_state_changed)
	MatchmakingManager.search_scope_changed.connect(_on_search_scope_changed)
	MatchmakingManager.match_candidate_found.connect(_on_match_candidate_found)
	MatchmakingManager.queue_error.connect(_on_queue_error)
	NetworkManager.lobby_state_changed.connect(_on_lobby_state_changed)
	NetworkManager.peer_joined.connect(_on_peer_joined)
	NetworkManager.peer_left.connect(_on_peer_left)
	NetworkManager.peer_updated.connect(_on_peer_updated)
	NetworkManager.party_reservation_result.connect(_on_party_reservation_result)
	NetworkManager.party_reservation_created.connect(_on_party_reservation_created)
	NetworkManager.party_reservation_consumed.connect(_on_party_reservation_consumed)
	NetworkManager.party_reservation_expired.connect(_on_party_reservation_expired)
	MatchAuthority.private_role_received.connect(_on_private_role_received)
	MatchAuthority.phase_synced.connect(_on_phase_synced)
	MatchAuthority.phase_timeout_triggered.connect(_on_phase_timeout_triggered)
	MatchAuthority.night_action_accepted.connect(_on_night_action_accepted)
	MatchAuthority.night_action_result_received.connect(_on_night_action_result_received)
	MatchAuthority.night_resolution_received.connect(_on_night_resolution_received)
	MatchAuthority.private_investigation_received.connect(_on_private_investigation_received)
	MatchAuthority.vote_accepted.connect(_on_vote_accepted)
	MatchAuthority.vote_resolution_received.connect(_on_vote_resolution_received)
	MatchAuthority.match_end_received.connect(_on_match_end_received)
	MatchAuthority.rematch_received.connect(_on_rematch_received)
	HostMigrationManager.backup_authority_changed.connect(_on_backup_authority_changed)
	HostMigrationManager.voluntary_transfer_completed.connect(_on_voluntary_transfer_completed)
	HostMigrationManager.voluntary_transfer_failed.connect(_on_voluntary_transfer_failed)
	HostMigrationManager.host_loss_detected.connect(_on_host_loss_detected)
	HostMigrationManager.host_loss_promotion_ready.connect(_on_host_loss_promotion_ready)
	HostMigrationManager.host_loss_recovery_timed_out.connect(
		_on_host_loss_recovery_timed_out
	)
	HostMigrationTransport.migrated_host_transport_ready.connect(_on_migrated_transport_ready)
	HostMigrationTransport.migrated_host_transport_failed.connect(_on_migrated_transport_failed)
	HostMigrationReconnect.reconnect_started.connect(_on_reconnect_started)
	HostMigrationReconnect.reconnect_identity_restored.connect(
		_on_reconnect_identity_restored
	)
	HostMigrationReconnect.reconnect_completed.connect(_on_reconnect_completed)
	HostMigrationReconnect.reconnect_failed.connect(_on_reconnect_failed)
	HostMigrationRestore.restore_completed.connect(_on_host_migration_restored)
	HostMigrationRestore.restore_failed.connect(_on_restore_failed)
	HostMigrationFallback.fallback_started.connect(_on_fallback_started)
	HostMigrationFallback.fallback_completed.connect(_on_fallback_completed)
	MatchLeaveManager.leave_started.connect(_on_leave_started)
	MatchLeaveManager.leave_completed.connect(_on_leave_completed)
	MatchLeaveManager.leave_rejected.connect(_on_leave_rejected)
	MatchLeaveManager.host_leave_cancelled.connect(_on_host_leave_cancelled)
	MatchLeaveManager.party_preservation_failed.connect(_on_party_preservation_failed)

func _log_initial_state() -> void:
	if Steamworks.initialized:
		_on_steam_ready()
	_on_party_changed()
	_on_queue_state_changed(MatchmakingManager.state)

func _on_steam_ready() -> void:
	_write_event(
		"steam_ready",
		{"steam_id": Steamworks.steam_id, "persona_name": Steamworks.persona_name},
	)

func _on_steam_unavailable(reason: String) -> void:
	_write_event("steam_unavailable", {"reason": reason})

func _on_party_changed() -> void:
	var current_members: Dictionary = PartyManager.state.members.duplicate(true)
	for raw_steam_id in current_members.keys():
		var steam_id := int(raw_steam_id)
		if not _last_party_members.has(steam_id):
			_write_event(
				"party_member_added",
				{"member_steam_id": steam_id, "party_size": current_members.size()},
			)
	for raw_steam_id in _last_party_members.keys():
		var steam_id := int(raw_steam_id)
		if not current_members.has(steam_id):
			_write_event(
				"party_member_removed",
				{"member_steam_id": steam_id, "party_size": current_members.size()},
			)
	_last_party_members = current_members
	_write_event(
		"party_changed",
		{
			"party_lobby_id": PartyManager.party_lobby_id,
			"leader_steam_id": PartyManager.state.leader_steam_id,
			"party_size": PartyManager.size(),
		},
	)

func _on_party_lobby_state_changed(state_name: StringName) -> void:
	_write_event(
		"party_lobby_state",
		{"state": str(state_name), "party_lobby_id": PartyManager.party_lobby_id},
	)
	match state_name:
		&"creating", &"joining":
			_party_lobby_transition = state_name
		&"ready":
			if _party_lobby_transition == &"creating":
				_write_event("party_created", {"party_id": PartyManager.party_lobby_id})
			elif _party_lobby_transition == &"joining":
				_write_event("party_joined", {"party_id": PartyManager.party_lobby_id})
			_party_lobby_transition = &""
		&"solo", &"offline":
			_party_lobby_transition = &""

func _on_match_target_changed(match_lobby_id: int) -> void:
	_write_event("match_target_changed", {"target_match_id": match_lobby_id})
	if match_lobby_id <= 0:
		_write_event("match_target_cleared")
	elif PartyManager.is_local_leader():
		_write_event("match_target_published", {"target_match_id": match_lobby_id})
	else:
		_write_event("match_target_observed", {"target_match_id": match_lobby_id})

func _on_queue_state_changed(state: StringName) -> void:
	_write_event(
		"matchmaking_state",
		{
			"state": str(state),
			"party_size": MatchmakingManager.local_party_size,
			"scope": MatchmakingManager.search_scope_name(),
		},
	)
	if state == &"searching":
		_write_event(
			"matchmaking_started",
			{
				"party_size": MatchmakingManager.local_party_size,
				"scope": MatchmakingManager.search_scope_name(),
			},
		)

func _on_search_scope_changed(distance_tier: int) -> void:
	_write_event(
		"matchmaking_scope_changed",
		{"distance_tier": distance_tier, "scope": MatchmakingManager.search_scope_name()},
	)

func _on_match_candidate_found(lobby_id: int, open_slots: int) -> void:
	_write_event(
		"match_candidate_found",
		{"match_id": lobby_id, "open_slots": open_slots},
	)

func _on_queue_error(message: String) -> void:
	_write_event("matchmaking_error", {"message": message})

func _on_lobby_state_changed(state: StringName) -> void:
	_write_event("lobby_state", {"state": str(state)})
	match state:
		&"creating":
			_write_event("match_lobby_creating")
		&"hosting":
			_write_event("match_lobby_created", {"match_id": NetworkManager.lobby_id})
			_write_event("transport_host_started", {"match_id": NetworkManager.lobby_id})
		&"in_lobby":
			_write_event("match_lobby_joined", {"match_id": NetworkManager.lobby_id})
			if (
				NetworkManager.lobby_id > 0
				and PartyManager.match_target_lobby_id == NetworkManager.lobby_id
			):
				_write_event("match_target_joined", {"match_id": NetworkManager.lobby_id})
		&"connected":
			_write_event(
				"transport_connected",
				{"match_id": NetworkManager.lobby_id, "peer_id": _local_peer_id()},
			)
		&"connection_failed":
			_write_event("transport_connection_failed")
		&"host_disconnected":
			_write_event("transport_host_disconnected")

func _on_peer_joined(peer_id: int) -> void:
	_write_event("peer_joined", _peer_payload(peer_id))

func _on_peer_left(peer_id: int) -> void:
	_write_event("peer_left", {"peer_id": peer_id})

func _on_peer_updated(peer_id: int) -> void:
	_write_event("peer_updated", _peer_payload(peer_id))

func _on_party_reservation_result(accepted: bool) -> void:
	_write_event(
		"reservation_result",
		{
			"accepted": accepted,
			"party_token": PartyManager.state.party_id,
			"party_size": PartyManager.size(),
		},
	)

func _on_party_reservation_created(
	party_token: int,
	party_size: int,
	peer_id: int,
	remaining_members: int,
) -> void:
	_write_event(
		"reservation_created",
		{
			"party_token": party_token,
			"party_size": party_size,
			"peer_id": peer_id,
			"remaining_members": remaining_members,
		},
	)

func _on_party_reservation_consumed(
	party_token: int,
	peer_id: int,
	remaining_members: int,
) -> void:
	_write_event(
		"reservation_consumed",
		{
			"party_token": party_token,
			"peer_id": peer_id,
			"remaining_members": remaining_members,
		},
	)

func _on_party_reservation_expired(party_token: int) -> void:
	_write_event("reservation_expired", {"party_token": party_token})

func _on_private_role_received(role: int) -> void:
	_write_event("local_role_received", {"local_role": role})

func _on_phase_synced(phase: int) -> void:
	_write_event("phase_synced", {"phase": phase})

func _on_phase_timeout_triggered(phase: int) -> void:
	_write_event("phase_timeout", {"phase": phase})

func _on_night_action_accepted(actor_peer_id: int, target_peer_id: int) -> void:
	_write_event(
		"night_action_accepted",
		{"actor_peer_id": actor_peer_id, "target_peer_id": target_peer_id},
	)

func _on_night_action_result_received(accepted: bool, target_peer_id: int) -> void:
	_write_event(
		"local_night_action_result",
		{"accepted": accepted, "target_peer_id": target_peer_id},
	)

func _on_night_resolution_received(killed_peer_ids: Array[int]) -> void:
	_write_event("night_resolution", {"killed_peer_ids": killed_peer_ids})

func _on_private_investigation_received(target_peer_id: int, is_heretic: bool) -> void:
	_write_event(
		"local_investigation",
		{"target_peer_id": target_peer_id, "is_heretic": is_heretic},
	)

func _on_vote_accepted(voter_peer_id: int, target_peer_id: int) -> void:
	_write_event(
		"vote_accepted",
		{"voter_peer_id": voter_peer_id, "target_peer_id": target_peer_id},
	)

func _on_vote_resolution_received(sacrificed_peer_id: int, tied: bool) -> void:
	_write_event(
		"vote_resolution",
		{"sacrificed_peer_id": sacrificed_peer_id, "tied": tied},
	)

func _on_match_end_received(winner: StringName) -> void:
	_write_event("match_end", {"winner": str(winner)})

func _on_rematch_received() -> void:
	_write_event("rematch")

func _on_backup_authority_changed(steam_id: int) -> void:
	_write_event("migration_backup_changed", {"backup_steam_id": steam_id})

func _on_voluntary_transfer_completed(steam_id: int) -> void:
	_write_event("migration_voluntary_transfer_completed", {"successor_steam_id": steam_id})

func _on_voluntary_transfer_failed(reason: String) -> void:
	_write_event("migration_voluntary_transfer_failed", {"reason": reason})

func _on_host_loss_detected(backup_steam_id: int) -> void:
	_write_event("migration_host_loss_detected", {"backup_steam_id": backup_steam_id})

func _on_host_loss_promotion_ready(backup_steam_id: int) -> void:
	_write_event("migration_promotion_ready", {"backup_steam_id": backup_steam_id})

func _on_host_loss_recovery_timed_out(backup_steam_id: int) -> void:
	_write_event("migration_recovery_timed_out", {"backup_steam_id": backup_steam_id})

func _on_migrated_transport_ready(steam_id: int) -> void:
	_write_event("migration_transport_ready", {"host_steam_id": steam_id})

func _on_migrated_transport_failed(reason: String) -> void:
	_write_event("migration_transport_failed", {"reason": reason})

func _on_reconnect_started(host_steam_id: int) -> void:
	_write_event("migration_reconnect_started", {"host_steam_id": host_steam_id})

func _on_reconnect_identity_restored(old_peer_id: int, new_peer_id: int, steam_id: int) -> void:
	_write_event(
		"migration_identity_restored",
		{"old_peer_id": old_peer_id, "new_peer_id": new_peer_id, "steam_id": steam_id},
	)

func _on_reconnect_completed(connected_players: int) -> void:
	_write_event("migration_reconnect_completed", {"connected_players": connected_players})

func _on_reconnect_failed(reason: String) -> void:
	_write_event("migration_reconnect_failed", {"reason": reason})

func _on_host_migration_restored(phase: int, round_number: int) -> void:
	_write_event("migration_match_restored", {"phase": phase, "round": round_number})

func _on_restore_failed(reason: String) -> void:
	_write_event("migration_restore_failed", {"reason": reason})

func _on_fallback_started(reason: String) -> void:
	_write_event("migration_fallback_started", {"reason": reason})

func _on_fallback_completed(reason: String) -> void:
	_write_event("migration_fallback_completed", {"reason": reason})

func _on_leave_started() -> void:
	_write_event("match_leave_started", {"was_host": NetworkManager.is_host})

func _on_leave_completed() -> void:
	_write_event("match_leave_completed")
	if PartyManager.party_lobby_id > 0:
		_write_event(
			"return_to_party",
			{
				"party_id": PartyManager.party_lobby_id,
				"leader_steam_id": PartyManager.state.leader_steam_id,
				"party_size": PartyManager.size(),
			},
		)

func _on_leave_rejected(reason: String) -> void:
	_write_event("match_leave_rejected", {"reason": reason})

func _on_host_leave_cancelled(reason: String) -> void:
	_write_event("host_leave_cancelled", {"reason": reason})

func _on_party_preservation_failed() -> void:
	_write_event("party_preservation_failed")

func _peer_payload(peer_id: int) -> Dictionary:
	var payload := {"peer_id": peer_id}
	if not NetworkManager.peers.has(peer_id):
		return payload
	var peer: Dictionary = NetworkManager.peers[peer_id]
	payload["steam_id"] = int(peer.get("steam_id", 0))
	payload["seat_id"] = int(peer.get("seat_id", -1))
	payload["ready"] = bool(peer.get("ready", false))
	return payload

func _local_peer_id() -> int:
	if NetworkManager.lobby_id <= 0 or multiplayer.multiplayer_peer == null:
		return 0
	return multiplayer.get_unique_id()

func _base_context() -> Dictionary:
	var roster_count := NetworkManager.peers.size()
	return {
		"monotonic_ms": Time.get_ticks_msec(),
		"unix_time": Time.get_unix_time_from_system(),
		"client": client_label,
		"steam_id": Steamworks.steam_id if Steamworks.initialized else 0,
		"peer_id": _local_peer_id(),
		"party_id": PartyManager.state.party_id,
		"target_match_id": PartyManager.match_target_lobby_id,
		"match_id": NetworkManager.lobby_id,
		"lobby_id": NetworkManager.lobby_id,
		"is_host": NetworkManager.is_host,
		"roster_count": roster_count,
		"open_slots": maxi(0, QuickMatchRules.TARGET_PLAYERS - roster_count),
		"queue_state": str(MatchmakingManager.state),
		"phase": int(GameManager.phase),
		"round": GameManager.round_number,
	}

func _write_event(event_name: String, payload: Dictionary = {}) -> void:
	if not enabled or _file == null:
		return
	var record := QAEventLogRules.make_record(event_name, payload, _base_context())
	if not QAEventLogRules.is_valid_record(record):
		push_warning("QAEventLog rejected invalid record for event %s" % event_name)
		return
	_file.store_line(JSON.stringify(record))
	_file.flush()
