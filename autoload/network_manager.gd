extends Node

signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal peer_updated(peer_id: int)
signal lobby_state_changed(state: StringName)
signal lobby_list_updated(lobbies: Array)
signal lobby_error(message: String)
signal lobby_start_requested

const MAX_PLAYERS: int = 10
const TECHNICAL_START_MIN_PLAYERS: int = LobbyRules.TECHNICAL_START_MIN_PLAYERS
const GAME_TAG_KEY: String = "game"
const GAME_TAG_VALUE: String = "GodsAndLiarsMVP"
const LOBBY_NAME_KEY: String = "name"

const STEAM_LOBBY_TYPE_PUBLIC := 2
const STEAM_LOBBY_COMPARISON_EQUAL := 3
const STEAM_RESULT_OK := 1
const STEAM_CHAT_ENTER_SUCCESS := 1

var is_host: bool = false
var lobby_id: int = 0
var peers: Dictionary = {}
var _steam: Object = null

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
	if not _require_steam():
		return
	lobby_state_changed.emit(&"creating")
	_steam.call("createLobby", STEAM_LOBBY_TYPE_PUBLIC, MAX_PLAYERS)

func join_lobby(target_lobby_id: int) -> void:
	if not _require_steam() or target_lobby_id <= 0:
		return
	lobby_state_changed.emit(&"joining")
	_steam.call("joinLobby", target_lobby_id)

func refresh_lobbies() -> void:
	if not _require_steam():
		return
	_steam.call("addRequestLobbyListStringFilter", GAME_TAG_KEY, GAME_TAG_VALUE, STEAM_LOBBY_COMPARISON_EQUAL)
	_steam.call("addRequestLobbyListResultCountFilter", 50)
	_steam.call("requestLobbyList")
	lobby_state_changed.emit(&"searching")

func leave_lobby() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	if _steam != null and lobby_id != 0:
		_steam.call("leaveLobby", lobby_id)
	Steamworks.lobby_id = 0
	reset()

func get_lobby_name(target_lobby_id: int) -> String:
	if _steam == null:
		return "Lobby %s" % target_lobby_id
	var value := str(_steam.call("getLobbyData", target_lobby_id, LOBBY_NAME_KEY))
	return value if not value.is_empty() else "Lobby %s" % target_lobby_id

func reset() -> void:
	is_host = false
	lobby_id = 0
	peers.clear()
	lobby_state_changed.emit(&"offline" if not Steamworks.initialized else &"steam_ready")

func register_peer(peer_id: int, steam_id: int = 0, display_name: String = "") -> void:
	if peer_id <= 0 or not IdentityPolicy.valid_identity(steam_id, display_name):
		return
	var previous: Dictionary = peers.get(peer_id, {})
	var is_new := previous.is_empty()
	peers[peer_id] = LobbyRules.make_peer(
		steam_id,
		IdentityPolicy.sanitize_display_name(display_name),
		bool(previous.get("ready", false)),
		int(previous.get("seat_id", -1)),
	)
	if is_new:
		peer_joined.emit(peer_id)
	else:
		peer_updated.emit(peer_id)

func unregister_peer(peer_id: int) -> void:
	if not peers.has(peer_id):
		return
	peers.erase(peer_id)
	peer_left.emit(peer_id)

func set_peer_ready(peer_id: int, ready: bool) -> void:
	if not peers.has(peer_id):
		return
	peers[peer_id]["ready"] = ready
	peer_updated.emit(peer_id)

func local_peer_ready() -> bool:
	if multiplayer.multiplayer_peer == null:
		return false
	return bool(peers.get(multiplayer.get_unique_id(), {}).get("ready", false))

func request_local_ready(ready: bool) -> void:
	if lobby_id == 0 or multiplayer.multiplayer_peer == null:
		return
	if multiplayer.is_server():
		_server_set_ready(multiplayer.get_unique_id(), ready)
	else:
		_request_ready.rpc_id(1, ready)

func can_host_start() -> bool:
	return LobbyRules.can_start(is_host, multiplayer.is_server(), peers, TECHNICAL_START_MIN_PLAYERS)

func request_host_start() -> void:
	if not can_host_start():
		lobby_error.emit("El host solo puede iniciar cuando hay al menos %d jugadores y todos están listos." % TECHNICAL_START_MIN_PLAYERS)
		return
	_start_lobby.rpc()

func all_peers_ready() -> bool:
	return LobbyRules.all_ready(peers, TECHNICAL_START_MIN_PLAYERS)

func _require_steam() -> bool:
	if not Steamworks.initialized or _steam == null:
		lobby_error.emit("Steam is not available. Run the project with a GodotSteam editor while Steam is open.")
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
	if host_steam_id == 0:
		peer.call("create_host", 0)
	else:
		peer.call("create_client", host_steam_id, 0)
	peer.set("server_relay", true)
	return peer

func _on_lobby_created(result: int, new_lobby_id: int) -> void:
	if result != STEAM_RESULT_OK:
		lobby_error.emit("Steam could not create lobby (result %s)." % result)
		lobby_state_changed.emit(&"steam_ready")
		return
	lobby_id = new_lobby_id
	Steamworks.lobby_id = new_lobby_id
	is_host = true
	_steam.call("setLobbyData", new_lobby_id, LOBBY_NAME_KEY, "%s's Ritual" % Steamworks.persona_name)
	_steam.call("setLobbyData", new_lobby_id, GAME_TAG_KEY, GAME_TAG_VALUE)
	var peer = _create_steam_peer()
	if peer == null:
		return
	multiplayer.multiplayer_peer = peer
	register_peer(1, Steamworks.steam_id, Steamworks.persona_name)
	lobby_state_changed.emit(&"hosting")

func _on_lobby_joined(joined_lobby_id: int, _permissions: int, _locked, response: int) -> void:
	if response != STEAM_CHAT_ENTER_SUCCESS:
		lobby_error.emit("Steam could not join lobby %s (response %s)." % [joined_lobby_id, response])
		lobby_state_changed.emit(&"steam_ready")
		return
	lobby_id = joined_lobby_id
	Steamworks.lobby_id = joined_lobby_id
	var host_steam_id := int(_steam.call("getLobbyOwner", joined_lobby_id))
	is_host = host_steam_id == Steamworks.steam_id
	if not is_host:
		var peer = _create_steam_peer(host_steam_id)
		if peer == null:
			return
		multiplayer.multiplayer_peer = peer
	lobby_state_changed.emit(&"in_lobby")

func _on_lobby_match_list(lobbies: Array) -> void:
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
	leave_lobby()

func _on_server_disconnected() -> void:
	lobby_error.emit("The ritual host disconnected.")
	leave_lobby()

@rpc("any_peer", "reliable")
func _announce_identity(client_steam_id: int, display_name: String) -> void:
	if not multiplayer.is_server() or not IdentityPolicy.valid_identity(client_steam_id, display_name):
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id <= 0 or peers.has(sender_id):
		return
	var clean_name := IdentityPolicy.sanitize_display_name(display_name)
	for existing_peer_id in peers.keys():
		var data: Dictionary = peers[existing_peer_id]
		_sync_peer.rpc_id(
			sender_id,
			int(existing_peer_id),
			int(data.get("steam_id", 0)),
			str(data.get("display_name", "")),
			bool(data.get("ready", false)),
		)
	_sync_peer.rpc(sender_id, client_steam_id, clean_name, false)

@rpc("authority", "call_local", "reliable")
func _sync_peer(peer_id: int, client_steam_id: int, display_name: String, ready: bool = false) -> void:
	register_peer(peer_id, client_steam_id, display_name)
	set_peer_ready(peer_id, ready)

@rpc("any_peer", "reliable")
func _request_ready(ready: bool) -> void:
	if not multiplayer.is_server():
		return
	_server_set_ready(multiplayer.get_remote_sender_id(), ready)

func _server_set_ready(peer_id: int, ready: bool) -> void:
	if not multiplayer.is_server() or not peers.has(peer_id):
		return
	_sync_ready.rpc(peer_id, ready)

@rpc("authority", "call_local", "reliable")
func _sync_ready(peer_id: int, ready: bool) -> void:
	set_peer_ready(peer_id, ready)

@rpc("authority", "call_local", "reliable")
func _start_lobby() -> void:
	GameManager.set_phase(GameManager.MatchPhase.READY)
	lobby_state_changed.emit(&"starting")
	lobby_start_requested.emit()

@rpc("authority", "call_local", "reliable")
func _remove_peer(peer_id: int) -> void:
	unregister_peer(peer_id)

func _on_steam_unavailable(reason: String) -> void:
	lobby_error.emit(reason)
	lobby_state_changed.emit(&"offline")
