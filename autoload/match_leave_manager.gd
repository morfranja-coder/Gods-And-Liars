extends Node

signal leave_started
signal leave_completed
signal leave_rejected(reason: String)
signal host_leave_requires_migration
signal host_leave_cancelled(reason: String)
signal party_preservation_failed

const LOBBY_SCENE := "res://scenes/lobby/lobby.tscn"

var leave_pending: bool = false
var last_leave_message: String = ""
var last_leave_error: String = ""
var _host_leave_pending: bool = false

func _ready() -> void:
	NetworkManager.lobby_state_changed.connect(_on_lobby_state_changed)
	HostMigrationManager.voluntary_transfer_completed.connect(_on_voluntary_transfer_completed)
	HostMigrationManager.voluntary_transfer_failed.connect(_on_voluntary_transfer_failed)

func request_leave_match() -> bool:
	if NetworkManager.is_host:
		return _request_host_leave()
	return _request_non_host_leave()

func _request_non_host_leave() -> bool:
	if not MatchLeaveRules.can_request_non_host_leave(
		NetworkManager.lobby_id,
		NetworkManager.is_host,
		multiplayer.multiplayer_peer != null,
		leave_pending,
	):
		_reject_leave("No hay una partida activa que pueda abandonarse.")
		return false
	leave_pending = true
	_host_leave_pending = false
	last_leave_error = ""
	leave_started.emit()
	_request_client_leave.rpc_id(1, Steamworks.steam_id)
	return true

func _request_host_leave() -> bool:
	if not MatchLeaveRules.can_request_host_leave(
		NetworkManager.lobby_id,
		NetworkManager.is_host,
		multiplayer.multiplayer_peer != null,
		leave_pending,
	):
		_reject_leave("El host no puede iniciar el abandono en este estado.")
		return false
	leave_pending = true
	_host_leave_pending = true
	last_leave_error = ""
	leave_started.emit()
	host_leave_requires_migration.emit()
	if HostMigrationManager.request_voluntary_host_exit():
		return true
	_cancel_host_leave(MatchLeaveRules.DEFAULT_HOST_TRANSFER_ERROR)
	return false

func consume_last_leave_message() -> String:
	var message := last_leave_message
	last_leave_message = ""
	return message

func consume_last_leave_error() -> String:
	var error_message := last_leave_error
	last_leave_error = ""
	return error_message

@rpc("any_peer", "reliable")
func _request_client_leave(client_steam_id: int) -> void:
	if not multiplayer.is_server() or not NetworkManager.is_host:
		return
	var sender_peer_id := multiplayer.get_remote_sender_id()
	if not MatchLeaveRules.server_accepts_leave(
		sender_peer_id,
		client_steam_id,
		NetworkManager.peers,
	):
		_client_leave_rejected.rpc_id(sender_peer_id, "Identidad de abandono inválida.")
		return
	_client_leave_accepted.rpc_id(sender_peer_id)
	NetworkManager._remove_peer.rpc(sender_peer_id)

@rpc("authority", "reliable")
func _client_leave_accepted() -> void:
	if not leave_pending or _host_leave_pending:
		return
	call_deferred("_complete_local_leave", false)

@rpc("authority", "reliable")
func _client_leave_rejected(reason: String) -> void:
	leave_pending = false
	_host_leave_pending = false
	_reject_leave(reason)

func _on_voluntary_transfer_completed(_successor_steam_id: int) -> void:
	if not leave_pending or not _host_leave_pending:
		return
	call_deferred("_complete_local_leave", true)

func _on_voluntary_transfer_failed(reason: String) -> void:
	if not leave_pending or not _host_leave_pending:
		return
	_cancel_host_leave(MatchLeaveRules.normalize_host_transfer_error(reason))

func _cancel_host_leave(reason: String) -> void:
	if not leave_pending or not _host_leave_pending:
		return
	leave_pending = false
	_host_leave_pending = false
	last_leave_error = reason
	host_leave_cancelled.emit(reason)
	leave_rejected.emit(reason)

func _reject_leave(reason: String) -> void:
	last_leave_error = reason
	leave_rejected.emit(reason)

func _capture_party_invariant() -> Dictionary:
	return MatchLeavePartyInvariant.capture(
		PartyManager.party_lobby_id,
		PartyManager.match_target_lobby_id,
		PartyManager.state.party_id,
		PartyManager.state.leader_steam_id,
		PartyManager.state.members,
	)

func _complete_local_leave(was_host: bool) -> void:
	if not leave_pending:
		return
	var party_before := _capture_party_invariant()
	leave_pending = false
	_host_leave_pending = false
	last_leave_error = ""
	last_leave_message = (
		"Transferiste el host y abandonaste la partida. Tu grupo se mantiene."
		if was_host
		else "Abandonaste la partida. Tu grupo se mantiene."
	)
	NetworkManager.leave_lobby()
	MatchmakingManager.reset()
	GameManager.reset_match()
	if not MatchLeavePartyInvariant.is_preserved(party_before, _capture_party_invariant()):
		push_error("Match leave mutated Party state; Party preservation invariant failed.")
		party_preservation_failed.emit()
	leave_completed.emit()
	var tree := get_tree()
	if tree == null:
		return
	var current := tree.current_scene
	if current == null or current.scene_file_path != LOBBY_SCENE:
		tree.change_scene_to_file(LOBBY_SCENE)

func _on_lobby_state_changed(state: StringName) -> void:
	if state in [&"offline", &"connection_failed"]:
		leave_pending = false
		_host_leave_pending = false
