extends Node

signal fallback_started(reason: String)
signal fallback_completed(reason: String)

const LOBBY_SCENE := "res://scenes/lobby/lobby.tscn"

var last_reason: String = ""
var fallback_active: bool = false

func _ready() -> void:
	HostMigrationManager.host_loss_recovery_timed_out.connect(_on_recovery_timed_out)
	HostMigrationTransport.migrated_host_transport_failed.connect(_on_transport_failed)
	HostMigrationReconnect.reconnect_failed.connect(_on_reconnect_failed)
	HostMigrationRestore.restore_failed.connect(_on_restore_failed)
	NetworkManager.lobby_state_changed.connect(_on_lobby_state_changed)

func consume_last_reason() -> String:
	var reason := last_reason
	last_reason = ""
	return reason

func request_fallback(reason: String) -> void:
	if fallback_active:
		return
	fallback_active = true
	last_reason = reason.strip_edges()
	if last_reason.is_empty():
		last_reason = "No se pudo completar la transferencia de host."
	fallback_started.emit(last_reason)
	_cleanup_match_session()
	call_deferred("_return_to_lobby")

func _cleanup_match_session() -> void:
	if NetworkManager.lobby_id != 0 or multiplayer.multiplayer_peer != null:
		NetworkManager.leave_lobby()
	if PartyManager.is_local_leader():
		PartyManager.clear_match_target()
	MatchmakingManager.reset()
	GameManager.reset_match()

func _return_to_lobby() -> void:
	var tree := get_tree()
	if tree == null:
		fallback_active = false
		return
	var current := tree.current_scene
	if current == null or current.scene_file_path != LOBBY_SCENE:
		tree.change_scene_to_file(LOBBY_SCENE)
	fallback_active = false
	fallback_completed.emit(last_reason)

func _on_recovery_timed_out(_backup_steam_id: int) -> void:
	request_fallback("La transferencia de host agotó el tiempo de recuperación.")

func _on_transport_failed(reason: String) -> void:
	request_fallback("No se pudo crear el nuevo host: %s" % reason)

func _on_reconnect_failed(reason: String) -> void:
	request_fallback("No se pudo reconectar la partida: %s" % reason)

func _on_restore_failed(reason: String) -> void:
	request_fallback("No se pudo restaurar la partida: %s" % reason)

func _on_lobby_state_changed(state: StringName) -> void:
	if state == &"host_disconnected":
		request_fallback("El host se desconectó y no había un sucesor recuperable.")
