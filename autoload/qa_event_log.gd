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
	_write_event("qa_log_started", {"client": client_label, "log_path": log_path})

func _exit_tree() -> void:
	if _file != null:
		_write_event("qa_log_stopped")
		_file.flush()
		_file.close()

func snapshot(label: String) -> void:
	if not enabled:
		return
	var peer_id := 0
	if multiplayer.multiplayer_peer != null:
		peer_id = multiplayer.get_unique_id()
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
			"peer_id": peer_id,
			"seat_id": seat_id,
			"phase": int(GameManager.phase),
			"round": GameManager.round_number,
			"local_role": int(MatchAuthority.local_role),
			"alive": alive,
			"winner": str(MatchAuthority.public_winner),
		},
	)

func _connect_signals() -> void:
	NetworkManager.lobby_state_changed.connect(_on_lobby_state_changed)
	NetworkManager.peer_updated.connect(_on_peer_updated)
	MatchAuthority.private_role_received.connect(_on_private_role_received)
	MatchAuthority.phase_synced.connect(_on_phase_synced)
	MatchAuthority.night_resolution_received.connect(_on_night_resolution_received)
	MatchAuthority.private_investigation_received.connect(_on_private_investigation_received)
	MatchAuthority.vote_resolution_received.connect(_on_vote_resolution_received)
	MatchAuthority.match_end_received.connect(_on_match_end_received)
	MatchAuthority.rematch_received.connect(_on_rematch_received)

func _on_lobby_state_changed(state: StringName) -> void:
	_write_event("lobby_state", {"state": str(state)})

func _on_peer_updated(peer_id: int) -> void:
	var seat_id := -1
	if NetworkManager.peers.has(peer_id):
		seat_id = int(NetworkManager.peers[peer_id].get("seat_id", -1))
	_write_event("peer_updated", {"peer_id": peer_id, "seat_id": seat_id})

func _on_private_role_received(role: int) -> void:
	_write_event("local_role_received", {"local_role": role})

func _on_phase_synced(phase: int) -> void:
	_write_event("phase_synced", {"phase": phase, "round": GameManager.round_number})

func _on_night_resolution_received(killed_peer_ids: Array[int]) -> void:
	_write_event("night_resolution", {"killed_peer_ids": killed_peer_ids})

func _on_private_investigation_received(target_peer_id: int, is_heretic: bool) -> void:
	_write_event(
		"local_investigation",
		{"target_peer_id": target_peer_id, "is_heretic": is_heretic},
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

func _sanitize_label(raw_label: String) -> String:
	var result := ""
	for character in raw_label.strip_edges().to_lower():
		if character.is_valid_identifier() or character.is_valid_int():
			result += character
		elif character in ["-", "_"]:
			result += character
	return result.left(32)

func _write_event(event_name: String, payload: Dictionary = {}) -> void:
	if not enabled or _file == null:
		return
	var record := {
		"unix_time": Time.get_unix_time_from_system(),
		"client": client_label,
		"event": event_name,
		"payload": payload,
	}
	_file.store_line(JSON.stringify(record))
	_file.flush()
