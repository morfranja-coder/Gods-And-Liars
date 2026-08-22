extends Node

signal restore_completed(phase: int, round_number: int)
signal restore_failed(reason: String)

func _ready() -> void:
	HostMigrationReconnect.reconnect_completed.connect(_on_reconnect_completed)
	NetworkManager.lobby_state_changed.connect(_on_lobby_state_changed)

func _on_reconnect_completed(_connected_players: int) -> void:
	if not NetworkManager.is_host or not multiplayer.is_server():
		return
	var remapped := HostMigrationSnapshotRemapper.remap(
		HostMigrationManager.backup_snapshot,
		HostMigrationReconnect.old_to_new_peer_ids,
	)
	if remapped == null:
		_fail("Could not remap authoritative snapshot after host migration.")
		return
	var restored_session := remapped.restore_session()
	if restored_session == null:
		_fail("Could not restore MatchSession after host migration.")
		return
	_apply_authoritative_state(remapped, restored_session)
	_sync_public_state.rpc(
		_build_public_alive(remapped),
		remapped.phase,
		remapped.round_number,
		remapped.public_winner,
	)
	_dispatch_private_roles(remapped)
	_arm_restored_deadline(remapped)
	NetworkManager.lobby_state_changed.emit(&"host_migration_restored")
	restore_completed.emit(remapped.phase, remapped.round_number)

func _apply_authoritative_state(snapshot: MatchSnapshot, session: MatchSession) -> void:
	MatchAuthority.set("_session", session)
	MatchAuthority.set("_roles_dispatched", snapshot.roles_dispatched)
	MatchAuthority.set("_role_acknowledged", snapshot.role_acknowledged.duplicate(true))
	MatchAuthority.set("_heretic_targets", snapshot.heretic_targets.duplicate(true))
	MatchAuthority.set("_healer_target_peer_id", snapshot.healer_target_peer_id)
	MatchAuthority.set("_inquisitor_target_peer_id", snapshot.inquisitor_target_peer_id)
	MatchAuthority.set("_votes", snapshot.votes.duplicate(true))
	MatchAuthority.public_alive_by_peer = _build_public_alive(snapshot)
	MatchAuthority.public_winner = StringName(snapshot.public_winner)
	GameManager.round_number = snapshot.round_number
	GameManager.set_phase(snapshot.phase)

func _build_public_alive(snapshot: MatchSnapshot) -> Dictionary:
	var result: Dictionary = {}
	for data in snapshot.players:
		var peer_id := int(data.get("peer_id", 0))
		if peer_id == HostMigrationSnapshotRemapper.DISCONNECTED_HOST_PEER_ID:
			continue
		result[peer_id] = bool(data.get("alive", false))
	return result

func _dispatch_private_roles(snapshot: MatchSnapshot) -> void:
	for data in snapshot.players:
		var peer_id := int(data.get("peer_id", 0))
		if peer_id == HostMigrationSnapshotRemapper.DISCONNECTED_HOST_PEER_ID:
			continue
		var role := int(data.get("role", int(PlayerState.Role.UNASSIGNED)))
		if peer_id == multiplayer.get_unique_id():
			MatchAuthority.call("_receive_private_role", role)
		else:
			MatchAuthority._receive_private_role.rpc_id(peer_id, role)
	MatchAuthority.call("_dispatch_private_roles")

func _arm_restored_deadline(snapshot: MatchSnapshot) -> void:
	if snapshot.phase_remaining_ms <= 0:
		MatchAuthority.set("_phase_deadline_ms", 0)
		MatchAuthority.set("_phase_deadline_phase", -1)
		return
	MatchAuthority.set(
		"_phase_deadline_ms",
		Time.get_ticks_msec() + snapshot.phase_remaining_ms,
	)
	MatchAuthority.set("_phase_deadline_phase", snapshot.phase)

@rpc("authority", "call_local", "reliable")
func _sync_public_state(
	alive_by_peer: Dictionary,
	phase_value: int,
	round_value: int,
	winner_value: String,
) -> void:
	MatchAuthority.public_alive_by_peer = alive_by_peer.duplicate(true)
	MatchAuthority.public_winner = StringName(winner_value)
	GameManager.round_number = round_value
	GameManager.set_phase(phase_value)
	MatchAuthority.phase_synced.emit(phase_value)

func _fail(reason: String) -> void:
	NetworkManager.lobby_state_changed.emit(&"host_migration_restore_failed")
	restore_failed.emit(reason)

func _on_lobby_state_changed(state: StringName) -> void:
	if state in [&"steam_ready", &"offline"]:
		pass
