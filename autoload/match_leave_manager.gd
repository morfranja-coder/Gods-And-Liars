extends Node

signal leave_started
signal leave_completed
signal leave_rejected(reason: String)
signal host_leave_requires_migration

const LOBBY_SCENE := "res://scenes/lobby/lobby.tscn"

var leave_pending: bool = false
var last_leave_message: String = ""

func _ready() -> void:
	NetworkManager.lobby_state_changed.connect(_on_lobby_state_changed)

func request_leave_match() -> bool:
	if NetworkManager.is_host:
		host_leave_requires_migration.emit()
		leave_rejected.emit("El host debe transferir autoridad antes de abandonar.")
		return false
	if not MatchLeaveRules.can_request_non_host_leave(
		NetworkManager.lobby_id,
		NetworkManager.is_host,
		multiplayer.multiplayer_peer != null,
		leave_pending,
	):
		leave_rejected.emit("No hay una partida activa que pueda abandonarse.")
		return false
	leave_pending = true
	leave_started.emit()
	_request_client_leave.rpc_id(1, Steamworks.steam_id)
	return true

func consume_last_leave_message() -> String:
	var message := last_leave_message
	last_leave_message = ""
	return message

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
	NetworkManager.call("_remove_peer").rpc(sender_peer_id)

@rpc("authority", "reliable")
func _client_leave_accepted() -> void:
	if not leave_pending:
		return
	call_deferred("_complete_local_leave")

@rpc("authority", "reliable")
func _client_leave_rejected(reason: String) -> void:
	leave_pending = false
	leave_rejected.emit(reason)

func _complete_local_leave() -> void:
	if not leave_pending:
		return
	leave_pending = false
	last_leave_message = "Abandonaste la partida. Tu grupo se mantiene."
	NetworkManager.leave_lobby()
	MatchmakingManager.reset()
	GameManager.reset_match()
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
