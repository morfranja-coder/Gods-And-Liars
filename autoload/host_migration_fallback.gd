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

func reset_after_match_leave() -> void:
	last_reason = ""
	fallback_active = false

func request_fallback(reason: String) -> void:
	if not HostMigrationFallbackRules.should_start(fallback_active):
		return
	fallback_active = true
	last_reason = HostMigrationFallbackRules.normalize_reason(reason)
	fallback_started.emit(last_reason)
	_cleanup_match_session()
	call_deferred("_return_to_lobby")

func _cleanup_match_session() -> void:
	if NetworkManager.lobby_id != 0 or multiplayer.multiplayer_peer != null:
		NetworkManager.leave_lobby()
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
		await tree.process_frame
	_show_reason_in_lobby()
	fallback_active = false
	fallback_completed.emit(last_reason)

func _show_reason_in_lobby() -> void:
	var current := get_tree().current_scene
	if current == null:
		return
	var status_label := current.get_node_or_null("%StatusLabel") as Label
	if status_label != null:
		status_label.text = "La partida terminó de forma segura: %s Tu grupo se mantiene." % last_reason

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