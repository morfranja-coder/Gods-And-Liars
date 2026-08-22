extends Node

const ENV_QA_LOG := "GODS_LIARS_QA_LOG"
const ENV_QA_CLIENT := "GODS_LIARS_QA_CLIENT"
const DEFAULT_LOG_PATH := "user://qa-session.log"

var enabled: bool = false
var client_label: String = ""
var _file: FileAccess = null

func _ready() -> void:
	enabled = OS.get_environment(ENV_QA_LOG) == "1"
	if not enabled:
		return
	client_label = _sanitize_label(OS.get_environment(ENV_QA_CLIENT))
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
	NetworkManager.lobby_state_changed.connect(_on_lobby_state_changed)
	NetworkManager.peer_joined.connect(_on_peer_joined)
	NetworkManager.peer_left.connect(_on_peer_left)
	NetworkManager.peer_updated.connect(_on_peer_updated)
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

func _on_lobby_state_changed(state: StringName) -> void:
	_write_event("lobby_state", {"state": str(state)})

func _on_peer_joined(peer_id: int) -> void:
	_write_event("peer_joined", _peer_payload(peer_id))

func _on_peer_left(peer_id: int) -> void:
	_write_event("peer_left", {"peer_id": peer_id})

func _on_peer_updated(peer_id: int) -> void:
	_write_event("peer_updated", _peer_payload(peer_id))

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

func _sanitize_label(raw_label: String) -> String:
	var result := ""
	for character in raw_label.strip_edges().to_lower():
		if character.is_valid_identifier() or character.is_valid_int():
			result += character
		elif character in ["-", "_"]:
			result += character
	return result.left(32)

func _local_peer_id() -> int:
	if multiplayer.multiplayer_peer == null:
		return 0
	return multiplayer.get_unique_id()

func _base_context() -> Dictionary:
	return {
		"monotonic_ms": Time.get_ticks_msec(),
		"unix_time": Time.get_unix_time_from_system(),
		"client": client_label,
		"steam_id": Steamworks.steam_id if Steamworks.initialized else 0,
		"peer_id": _local_peer_id(),
		"lobby_id": NetworkManager.lobby_id,
		"is_host": NetworkManager.is_host,
		"phase": int(GameManager.phase),
		"round": GameManager.round_number,
	}

func _write_event(event_name: String, payload: Dictionary = {}) -> void:
	if not enabled or _file == null:
		return
	var record := _base_context()
	record["event"] = event_name
	record["payload"] = payload
	_file.store_line(JSON.stringify(record))
	_file.flush()
