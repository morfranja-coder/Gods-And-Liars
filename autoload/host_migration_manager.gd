extends Node

signal backup_authority_changed(steam_id: int)
signal backup_snapshot_received(sequence: int)

const SNAPSHOT_REFRESH_INTERVAL_MS := 250

var backup_authority_steam_id: int = 0
var backup_authority_peer_id: int = 0
var backup_snapshot: MatchSnapshot = null
var backup_sequence: int = 0
var _last_sent_json: String = ""
var _last_refresh_ms: int = 0

func _process(_delta: float) -> void:
	if not multiplayer.is_server() or not NetworkManager.is_host:
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
	_last_sent_json = ""
	_last_refresh_ms = 0

func has_valid_backup_snapshot() -> bool:
	return backup_snapshot != null and backup_snapshot.is_valid()

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
	backup_authority_steam_id = next_steam_id
	backup_authority_peer_id = next_peer_id
	_last_sent_json = ""
	backup_authority_changed.emit(backup_authority_steam_id)

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
