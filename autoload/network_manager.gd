extends Node

signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal peer_updated(peer_id: int)
signal lobby_state_changed(state: StringName)
signal lobby_list_updated(lobbies: Array)
signal lobby_error(message: String)
signal lobby_start_requested

const MAX_PLAYERS: int = QuickMatchRules.TARGET_PLAYERS
const TECHNICAL_START_MIN_PLAYERS: int = LobbyRules.TECHNICAL_START_MIN_PLAYERS
const GAMEPLAY_START_PLAYERS: int = QuickMatchRules.TARGET_PLAYERS
const GAME_TAG_KEY: String = "game"
const GAME_TAG_VALUE: String = "GodsAndLiarsMVP"
const LOBBY_NAME_KEY: String = "name"
const LOBBY_KIND_KEY: String = "kind"
const LOBBY_KIND_MATCH: String = "match"
const MATCH_STATE_KEY: String = "match_state"
const MATCH_STATE_OPEN: String = "open"
const MATCH_STATE_STARTED: String = "started"
const OPEN_SLOTS_KEY: String = "open_slots"

const STEAM_LOBBY_TYPE_PUBLIC := 2
const STEAM_LOBBY_TYPE_INVISIBLE := 3
const STEAM_LOBBY_COMPARISON_EQUAL := 0
const STEAM_LOBBY_DISTANCE_WORLDWIDE := 3
const STEAM_RESULT_OK := 1
const STEAM_CHAT_ENTER_SUCCESS := 1

var is_host: bool = false
var lobby_id: int = 0
var lobby_started: bool = false
var peers: Dictionary = {}
var _steam: Object = null
var _last_ready_request_ms: Dictionary = {}
var _pending_create_match: bool = false
var _pending_create_lobby_type: int = STEAM_LOBBY_TYPE_PUBLIC
var _pending_join_match_id: int = 0
var _pending_match_search: bool = false
var _reserved_party_steam_ids: Array[int] = []

func _ready() -> void:
	Steamworks.steam_ready.connect(_bind_steam_callbacks)
	Steamworks.steam_unavailable.connect(_on_steam_unavailable)
	if Steamworks.initialized:
		_bind_steam_callbacks()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _bind_steam_callbacks() -> void:
	_steam = Steamworks.get_api()
	if _steam == null:
		return
	_connect_steam_signal("lobby_created", _on_lobby_created)
	_connect_steam_signal("lobby_joined", _on_lobby_joined)
	_connect_steam_signal("lobby_match_list", _on_lobby_match_list)
	lobby_state_changed.emit(&"steam_ready")

func _connect_steam_signal(signal_name: StringName, method: Callable) -> void:
	if _steam.has_signal(signal_name) and not _steam.is_connected(signal_name, method):
		_steam.connect(signal_name, method)

func host_lobby() -> void:
	_begin_host_lobby(STEAM_LOBBY_TYPE_PUBLIC, [])

func host_quick_match_lobby(party_member_ids: Array[int]) -> void:
	var reserved_ids: Array[int] = []
	for steam_id in party_member_ids:
		if steam_id > 0 and steam_id != Steamworks.steam_id:
			reserved_ids.append(steam_id)
	_begin_host_lobby(STEAM_LOBBY_TYPE_INVISIBLE, reserved_ids)

func _begin_host_lobby(lobby_type: int, reserved_ids: Array[int]) -> void:
	if not _require_steam() or _pending_create_match or lobby_id != 0:
		return
	_pending_create_match = true
	_pending_create_lobby_type = lobby_type
	_reserved_party_steam_ids = reserved_ids.duplicate()
	lobby_state_changed.emit(&"creating")
	_steam.call("createLobby", lobby_type, MAX_PLAYERS)

func join_lobby(target_lobby_id: int) -> void:
	if not _require_steam() or target_lobby_id <= 0:
		return
	_pending_join_match_id = target_lobby_id
	lobby_state_changed.emit(&"joining")
	_steam.call("joinLobby", target_lobby_id)

func refresh_lobbies() -> void:
	if not _require_steam() or _pending_match_search:
		return
	_pending_match_search = true
	_steam.call(
		"addRequestLobbyListStringFilter",
		GAME_TAG_KEY,
		GAME_TAG_VALUE,
		STEAM_LOBBY_COMPARISON_EQUAL,
	)
	_steam.call(
		"addRequestLobbyListStringFilter",
		LOBBY_KIND_KEY,
		LOBBY_KIND_MATCH,
		STEAM_LOBBY_COMPARISON_EQUAL,
	)
	_steam.call("addRequestLobbyListDistanceFilter", STEAM_LOBBY_DISTANCE_WORLDWIDE)
	_steam.call("addRequestLobbyListResultCountFilter", 50)
	_steam.call("requestLobbyList")
	lobby_state_changed.emit(&"searching")

func leave_lobby() -> void:
	_teardown_lobby(&"steam_ready" if Steamworks.initialized else &"offline")

func get_lobby_name(target_lobby_id: int) -> String:
	if _steam == null:
		return "Lobby %s" % target_lobby_id
	var value := str(_steam.call("getLobbyData", target_lobby_id, LOBBY_NAME_KEY))
	return value if not value.is_empty() else "Lobby %s" % target_lobby_id

func reset() -> void:
	_clear_session_state()
	lobby_state_changed.emit(&"offline" if not Steamworks.initialized else &"steam_ready")

func register_peer(peer_id: int, steam_id: int = 0, display_name: String = "", seat_id: int = -1) -> void:
	if lobby_started:
		return
	if not LobbyRules.can_register_peer(peers, peer_id, MAX_PLAYERS):
		return
	if not IdentityPolicy.valid_identity(steam_id, display_name):
		return
	if IdentityPolicy.steam_id_in_use(peers, steam_id, peer_id):
		return
	var previous: Dictionary = peers.get(peer_id, {})
	var is_new := previous.is_empty()
	var previous_seat := int(previous.get("seat_id", -1))
	var resolved_seat := previous_seat if SeatAllocator.is_valid_seat(previous_seat) else seat_id
	if not SeatAllocator.is_valid_seat(resolved_seat):
		resolved_seat = SeatAllocator.first_free_seat(peers)
	if not SeatAllocator.seat_is_available(peers, resolved_seat, peer_id):
		return
	peers[peer_id] = LobbyRules.make_peer(
		steam_id,
		IdentityPolicy.sanitize_display_name(display_name),
		bool(previous.get("ready", false)),
		resolved_seat,
	)
	_reserved_party_steam_ids.erase(steam_id)
	if is_new:
		peer_joined.emit(peer_id)
	else:
		peer_updated.emit(peer_id)
	_publish_match_capacity()

func unregister_peer(peer_id: int) -> void:
	if not peers.has(peer_id):
		return
	peers.erase(peer_id)
	_last_ready_request_ms.erase(peer_id)
	peer_left.emit(peer_id)
	_publish_match_capacity()

func set_peer_ready(peer_id: int, ready: bool) -> void:
	if lobby_started or not peers.has(peer_id):
		return
	peers[peer_id]["ready"] = ready
	peer_updated.emit(peer_id)

func local_peer_ready() -> bool:
	if multiplayer.multiplayer_peer == null:
		return false
	return bool(peers.get(multiplayer.get_unique_id(), {}).get("ready", false))

func request_local_ready(ready: bool) -> void:
	if lobby_started or lobby_id == 0 or multiplayer.multiplayer_peer == null:
		return
	if multiplayer.is_server():
		_server_set_ready(multiplayer.get_unique_id(), ready)
	else:
		_request_ready.rpc_id(1, ready)

func can_host_start() -> bool:
	if lobby_started:
		return false
	return LobbyRules.can_start_exact(
		is_host,
		multiplayer.is_server(),
		peers,
		GAMEPLAY_START_PLAYERS,
	)

func request_host_start() -> void:
	if lobby_started:
		return
	if not can_host_start():
		lobby_error.emit(
			"La partida requiere exactamente %d jugadores y todos deben estar listos."
			% GAMEPLAY_START_PLAYERS
		)
		return
	_start_lobby.rpc()

func all_peers_ready() -> bool:
	return LobbyRules.all_ready(peers, TECHNICAL_START_MIN_PLAYERS)

func advertised_open_slots() -> int:
	return maxi(0, MAX_PLAYERS - peers.size() - _reserved_party_steam_ids.size())

func _publish_match_capacity() -> void:
	if not is_host or _steam == null or lobby_id == 0:
		return
	var open_slots := advertised_open_slots()
	_steam.call("setLobbyData", lobby_id, OPEN_SLOTS_KEY, str(open_slots))
	_steam.call(
		"setLobbyData",
		lobby_id,
		MATCH_STATE_KEY,
		MATCH_STATE_STARTED if lobby_started else MATCH_STATE_OPEN,
	)
	if _steam.has_method("setLobbyJoinable"):
		_steam.call("setLobbyJoinable", lobby_id, not lobby_started and open_slots > 0)

func _clear_pending_operations() -> void:
	_pending_create_match = false
	_pending_create_lobby_type = STEAM_LOBBY_TYPE_PUBLIC
	_pending_join_match_id = 0
	_pending_match_search = false

func _clear_session_state() -> void:
	is_host = false
	lobby_id = 0
	lobby_started = false
	peers.clear()
	_last_ready_request_ms.clear()
	_reserved_party_steam_ids.clear()
	_clear_pending_operations()

func _teardown_lobby(final_state: StringName) -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	if _steam != null and lobby_id != 0:
		_steam.call("leaveLobby", lobby_id)
	Steamworks.lobby_id = 0
	_clear_session_state()
	lobby_state_changed.emit(final_state)

func _require_steam() -> bool:
	if not Steamworks.initialized or _steam == null:
		lobby_error.emit(
			"Steam is not available. Run the project with a GodotSteam editor while Steam is open."
		)
		return false
	if not ClassDB.class_exists("SteamMultiplayerPeer"):
		lobby_error.emit("SteamMultiplayerPeer is unavailable in this Godot build.")
		return false
	return true

func _create_steam_peer(host_steam_id: int = 0):
	var peer = ClassDB.instantiate("SteamMultiplayerPeer")
	if peer == null:
		lobby_error.emit("Could not instantiate SteamMultiplayerPeer.")
		return null
	var create_result
	if host_steam_id == 0:
		create_result = peer.call("create_host", 0)
	else:
		create_result = peer.call("create_client", host_steam_id, 0)
	if create_result != null and int(create_result) != OK:
		lobby_error.emit("Steam multiplayer peer creation failed (error %s)." % create_result)
		return null
	peer.set("server_relay", true)
	return peer

func _on_lobby_created(result: int, new_lobby_id: int) -> void:
	if not _pending_create_match:
		return
	_pending_create_match = false
	if result != STEAM_RESULT_OK:
		_reserved_party_steam_ids.clear()
		lobby_error.emit("Steam could not create lobby (result %s)." % result)
		lobby_state_changed.emit(&"steam_ready")
		return
	lobby_id = new_lobby_id
	Steamworks.lobby_id = new_lobby_id
	is_host = true
	lobby_started = false
	_steam.call(
		"setLobbyData",
		new_lobby_id,
		LOBBY_NAME_KEY,
		"%s's Ritual" % Steamworks.persona_name,
	)
	_steam.call("setLobbyData", new_lobby_id, GAME_TAG_KEY, GAME_TAG_VALUE)
	_steam.call("setLobbyData", new_lobby_id, LOBBY_KIND_KEY, LOBBY_KIND_MATCH)
	_steam.call("setLobbyData", new_lobby_id, MATCH_STATE_KEY, MATCH_STATE_OPEN)
	var peer = _create_steam_peer()
	if peer == null:
		_teardown_lobby(&"steam_ready")
		return
	multiplayer.multiplayer_peer = peer
	register_peer(1, Steamworks.steam_id, Steamworks.persona_name)
	_publish_match_capacity()
	lobby_state_changed.emit(&"hosting")

func _on_lobby_joined(joined_lobby_id: int, _permissions: int, _locked, response: int) -> void:
	if joined_lobby_id != _pending_join_match_id:
		return
	_pending_join_match_id = 0
	if response != STEAM_CHAT_ENTER_SUCCESS:
		lobby_error.emit(
			"Steam could not join lobby %s (response %s)." % [joined_lobby_id, response]
		)
		lobby_state_changed.emit(&"steam_ready")
		return
	lobby_id = joined_lobby_id
	Steamworks.lobby_id = joined_lobby_id
	lobby_started = false
	var host_steam_id := int(_steam.call("getLobbyOwner", joined_lobby_id))
	is_host = host_steam_id == Steamworks.steam_id
	if not is_host:
		var peer = _create_steam_peer(host_steam_id)
		if peer == null:
			_teardown_lobby(&"steam_ready")
			return
		multiplayer.multiplayer_peer = peer
	lobby_state_changed.emit(&"in_lobby")

func _on_lobby_match_list(lobbies: Array) -> void:
	if not _pending_match_search:
		return
	_pending_match_search = false
	lobby_list_updated.emit(lobbies)
	lobby_state_changed.emit(&"steam_ready")

func _on_peer_connected(_peer_id: int) -> void:
	pass

func _on_peer_disconnected(peer_id: int) -> void:
	if multiplayer.is_server():
		_remove_peer.rpc(peer_id)
	else:
		unregister_peer(peer_id)

func _on_connected_to_server() -> void:
	_announce_identity.rpc_id(1, Steamworks.steam_id, Steamworks.persona_name)
	lobby_state_changed.emit(&"connected")

func _on_connection_failed() -> void:
	lobby_error.emit("Could not establish the Steam multiplayer connection.")
	_teardown_lobby(&"connection_failed")

func _on_server_disconnected() -> void:
	lobby_error.emit("The ritual host disconnected.")
	_teardown_lobby(&"host_disconnected")

@rpc("any_peer", "reliable")
func _announce_identity(client_steam_id: int, display_name: String) -> void:
	if lobby_started or not multiplayer.is_server():
		return
	if not IdentityPolicy.valid_identity(client_steam_id, display_name):
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if not LobbyRules.can_register_peer(peers, sender_id, MAX_PLAYERS):
		return
	if IdentityPolicy.steam_id_in_use(peers, client_steam_id, sender_id):
		return
	var clean_name := IdentityPolicy.sanitize_display_name(display_name)
	var assigned_seat := SeatAllocator.first_free_seat(peers)
	if not SeatAllocator.is_valid_seat(assigned_seat):
		return
	for existing_peer_id in peers.keys():
		var data: Dictionary = peers[existing_peer_id]
		_sync_peer.rpc_id(
			sender_id,
			int(existing_peer_id),
			int(data.get("steam_id", 0)),
			str(data.get("display_name", "")),
			bool(data.get("ready", false)),
			int(data.get("seat_id", -1)),
		)
	_sync_peer.rpc(sender_id, client_steam_id, clean_name, false, assigned_seat)

@rpc("authority", "call_local", "reliable")
func _sync_peer(
	peer_id: int,
	client_steam_id: int,
	display_name: String,
	ready: bool = false,
	seat_id: int = -1,
) -> void:
	register_peer(peer_id, client_steam_id, display_name, seat_id)
	set_peer_ready(peer_id, ready)

@rpc("any_peer", "reliable")
func _request_ready(ready: bool) -> void:
	if lobby_started or not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if not peers.has(sender_id):
		return
	var now_ms := Time.get_ticks_msec()
	var last_ms := int(_last_ready_request_ms.get(sender_id, 0))
	if not RateLimitPolicy.can_accept(last_ms, now_ms):
		return
	_last_ready_request_ms[sender_id] = now_ms
	_server_set_ready(sender_id, ready)

func _server_set_ready(peer_id: int, ready: bool) -> void:
	if lobby_started or not multiplayer.is_server() or not peers.has(peer_id):
		return
	_sync_ready.rpc(peer_id, ready)

@rpc("authority", "call_local", "reliable")
func _sync_ready(peer_id: int, ready: bool) -> void:
	set_peer_ready(peer_id, ready)

@rpc("authority", "call_local", "reliable")
func _start_lobby() -> void:
	if lobby_started:
		return
	lobby_started = true
	_publish_match_capacity()
	GameManager.set_phase(GameManager.MatchPhase.READY)
	lobby_state_changed.emit(&"starting")
	lobby_start_requested.emit()

@rpc("authority", "call_local", "reliable")
func _remove_peer(peer_id: int) -> void:
	unregister_peer(peer_id)

func _on_steam_unavailable(reason: String) -> void:
	_clear_pending_operations()
	lobby_error.emit(reason)
	lobby_state_changed.emit(&"offline")
