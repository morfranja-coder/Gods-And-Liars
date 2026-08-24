extends Node

signal backup_authority_changed(steam_id: int)
signal backup_snapshot_received(sequence: int)
signal voluntary_transfer_completed(steam_id: int)
signal voluntary_transfer_failed(reason: String)
signal host_loss_detected(backup_steam_id: int)
signal host_loss_waiting(backup_steam_id: int, observed_owner_steam_id: int)
signal host_loss_promotion_ready(backup_steam_id: int)
signal host_loss_recovery_timed_out(backup_steam_id: int)

const SNAPSHOT_REFRESH_INTERVAL_MS := 250
const OWNER_POLL_INTERVAL_MS := 200
const HOST_LOSS_RECOVERY_TIMEOUT_MS := 8000

var backup_authority_steam_id: int = 0
var backup_authority_peer_id: int = 0
var backup_snapshot: MatchSnapshot = null
var backup_sequence: int = 0
var host_loss_recovery_active: bool = false
var observed_lobby_owner_steam_id: int = 0
var _last_sent_json: String = ""
var _last_refresh_ms: int = 0
var _host_loss_started_ms: int = 0
var _last_owner_poll_ms: int = 0
var _ownership_handoff_requested: bool = false
var _recovery_state: StringName = &""

func _ready() -> void:
	NetworkManager.lobby_state_changed.connect(_on_lobby_state_changed)
	var legacy_handler := Callable(NetworkManager, "_on_server_disconnected")
	if multiplayer.server_disconnected.is_connected(legacy_handler):
		multiplayer.server_disconnected.disconnect(legacy_handler)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)

func _process(_delta: float) -> void:
	if host_loss_recovery_active:
		_process_host_loss_recovery()
		return
	if not NetworkManager.is_host or multiplayer.multiplayer_peer == null:
		return
	if not multiplayer.is_server():
		return
	var session = MatchAuthority.get("_session")
	if session == null:
		return
	var now_ms := Time.get_ticks_msec()
	if now_ms - _last_refresh_ms < SNAPSHOT_REFRESH_INTERVAL_MS:
		return
	_last_refresh_ms = now_ms
	_refresh_backup_authority()
	_send_snapshot_if_changed(now_ms)

func reset() -> void:
	backup_authority_steam_id = 0
	backup_authority_peer_id = 0
	backup_snapshot = null
	backup_sequence = 0
	host_loss_recovery_active = false
	observed_lobby_owner_steam_id = 0
	_last_sent_json = ""
	_last_refresh_ms = 0
	_host_loss_started_ms = 0
	_last_owner_poll_ms = 0
	_ownership_handoff_requested = false
	_recovery_state = &""

func has_valid_backup_snapshot() -> bool:
	return backup_snapshot != null and backup_snapshot.is_valid()

func request_voluntary_host_exit() -> bool:
	if not multiplayer.is_server() or not NetworkManager.is_host:
		return _fail_voluntary_transfer("Only the active host can transfer lobby ownership.")
	var steam := Steamworks.get_api()
	if steam == null:
		return _fail_voluntary_transfer("Steam API is unavailable.")
	if not VoluntaryHostTransferRules.can_transfer(
		NetworkManager.lobby_id,
		Steamworks.steam_id,
		backup_authority_steam_id,
		backup_authority_peer_id,
		NetworkManager.peers,
		has_valid_backup_snapshot(),
	):
		return _fail_voluntary_transfer("No valid backup authority is ready for host transfer.")
	if not steam.has_method("setLobbyOwner"):
		return _fail_voluntary_transfer("Steam lobby ownership transfer is unavailable.")
	var transferred := bool(
		steam.call("setLobbyOwner", NetworkManager.lobby_id, backup_authority_steam_id)
	)
	if not transferred:
		return _fail_voluntary_transfer("Steam rejected the lobby ownership transfer.")
	voluntary_transfer_completed.emit(backup_authority_steam_id)
	return true

func _fail_voluntary_transfer(reason: String) -> bool:
	voluntary_transfer_failed.emit(reason)
	return false

func _refresh_backup_authority() -> void:
	var next_steam_id := BackupAuthorityRules.keep_or_choose_backup(
		NetworkManager.peers,
		MatchAuthority.public_alive_by_peer,
		Steamworks.steam_id,
		backup_authority_steam_id,
	)
	var next_peer_id := BackupAuthorityRules.peer_id_for_steam_id(
		NetworkManager.peers,
		next_steam_id,
	)
	if next_steam_id == backup_authority_steam_id and next_peer_id == backup_authority_peer_id:
		return
	_last_sent_json = ""
	_sync_backup_authority.rpc(next_steam_id)

func _send_snapshot_if_changed(now_ms: int) -> void:
	if backup_authority_steam_id <= 0 or backup_authority_peer_id <= 0:
		return
	var snapshot := _capture_snapshot(now_ms)
	if snapshot == null:
		return
	var snapshot_json := snapshot.to_json()
	if snapshot_json == _last_sent_json:
		return
	backup_sequence += 1
	_last_sent_json = snapshot_json
	_receive_backup_snapshot.rpc_id(
		backup_authority_peer_id,
		backup_authority_steam_id,
		backup_sequence,
		snapshot_json,
	)

func _capture_snapshot(now_ms: int) -> MatchSnapshot:
	var session: MatchSession = MatchAuthority.get("_session")
	if session == null:
		return null
	var deadline_ms := int(MatchAuthority.get("_phase_deadline_ms"))
	var deadline_phase := int(MatchAuthority.get("_phase_deadline_phase"))
	var remaining_ms := 0
	if deadline_ms > 0 and deadline_phase == int(GameManager.phase):
		remaining_ms = maxi(0, deadline_ms - now_ms)
	return MatchSnapshot.from_runtime(
		session,
		int(GameManager.phase),
		GameManager.round_number,
		remaining_ms,
		MatchAuthority.public_winner,
		bool(MatchAuthority.get("_roles_dispatched")),
		MatchAuthority.get("_role_acknowledged"),
		MatchAuthority.get("_heretic_targets"),
		int(MatchAuthority.get("_healer_target_peer_id")),
		int(MatchAuthority.get("_inquisitor_target_peer_id")),
		MatchAuthority.get("_votes"),
	)

func _on_server_disconnected() -> void:
	if NetworkManager.lobby_id <= 0 or backup_authority_steam_id <= 0:
		NetworkManager.call("_on_server_disconnected")
		return
	_detach_failed_transport()
	host_loss_recovery_active = true
	_host_loss_started_ms = Time.get_ticks_msec()
	_last_owner_poll_ms = 0
	observed_lobby_owner_steam_id = 0
	_ownership_handoff_requested = false
	_recovery_state = &"host_migration_recovering"
	NetworkManager.lobby_state_changed.emit(_recovery_state)
	host_loss_detected.emit(backup_authority_steam_id)

func _detach_failed_transport() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	NetworkManager.is_host = false

func _process_host_loss_recovery() -> void:
	var now_ms := Time.get_ticks_msec()
	if now_ms - _host_loss_started_ms >= HOST_LOSS_RECOVERY_TIMEOUT_MS:
		_timeout_host_loss_recovery()
		return
	if now_ms - _last_owner_poll_ms < OWNER_POLL_INTERVAL_MS:
		return
	_last_owner_poll_ms = now_ms
	var steam := Steamworks.get_api()
	if steam == null or NetworkManager.lobby_id <= 0:
		return
	observed_lobby_owner_steam_id = int(steam.call("getLobbyOwner", NetworkManager.lobby_id))
	var role := HostLossRecoveryRules.role_for(
		Steamworks.steam_id,
		backup_authority_steam_id,
		observed_lobby_owner_steam_id,
		has_valid_backup_snapshot(),
	)
	if HostLossRecoveryRules.owner_confirms_backup(
		observed_lobby_owner_steam_id,
		backup_authority_steam_id,
	):
		_handle_confirmed_backup_owner(role)
		return
	if role == HostLossRecoveryRules.RecoveryRole.TEMPORARY_OWNER:
		_try_handoff_temporary_owner(steam)
	_set_waiting_state()

func _handle_confirmed_backup_owner(role: HostLossRecoveryRules.RecoveryRole) -> void:
	if role != HostLossRecoveryRules.RecoveryRole.BACKUP:
		_set_waiting_state()
		return
	host_loss_recovery_active = false
	_recovery_state = &"host_migration_promotion_ready"
	NetworkManager.lobby_state_changed.emit(_recovery_state)
	host_loss_promotion_ready.emit(backup_authority_steam_id)

func _try_handoff_temporary_owner(steam: Object) -> void:
	if _ownership_handoff_requested or not steam.has_method("setLobbyOwner"):
		return
	if not HostLossRecoveryRules.should_handoff_temporary_owner(
		Steamworks.steam_id,
		backup_authority_steam_id,
		observed_lobby_owner_steam_id,
	):
		return
	_ownership_handoff_requested = bool(
		steam.call("setLobbyOwner", NetworkManager.lobby_id, backup_authority_steam_id)
	)

func _set_waiting_state() -> void:
	if _recovery_state == &"host_migration_waiting":
		return
	_recovery_state = &"host_migration_waiting"
	NetworkManager.lobby_state_changed.emit(_recovery_state)
	host_loss_waiting.emit(backup_authority_steam_id, observed_lobby_owner_steam_id)

func _timeout_host_loss_recovery() -> void:
	host_loss_recovery_active = false
	_recovery_state = &"host_migration_timed_out"
	NetworkManager.lobby_state_changed.emit(_recovery_state)
	host_loss_recovery_timed_out.emit(backup_authority_steam_id)

@rpc("authority", "call_local", "reliable")
func _sync_backup_authority(steam_id: int) -> void:
	backup_authority_steam_id = maxi(0, steam_id)
	backup_authority_peer_id = BackupAuthorityRules.peer_id_for_steam_id(
		NetworkManager.peers,
		backup_authority_steam_id,
	)
	backup_authority_changed.emit(backup_authority_steam_id)

@rpc("authority", "call_remote", "reliable")
func _receive_backup_snapshot(
	intended_steam_id: int,
	sequence: int,
	snapshot_json: String,
) -> void:
	if intended_steam_id <= 0 or intended_steam_id != Steamworks.steam_id:
		return
	if sequence <= backup_sequence:
		return
	var parsed := MatchSnapshot.from_json(snapshot_json)
	if parsed == null:
		return
	backup_authority_steam_id = intended_steam_id
	backup_sequence = sequence
	backup_snapshot = parsed
	backup_snapshot_received.emit(sequence)

func _on_lobby_state_changed(state: StringName) -> void:
	if state in [&"steam_ready", &"offline", &"connection_failed"]:
		reset()
