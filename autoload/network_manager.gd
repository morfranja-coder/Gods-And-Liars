extends Node

signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal lobby_state_changed(state: StringName)
signal lobby_list_updated(lobbies: Array)
signal lobby_error(message: String)

const MAX_PLAYERS: int = 10
const GAME_TAG_KEY: String = "game"
const GAME_TAG_VALUE: String = "GodsAndLiarsMVP"
const LOBBY_NAME_KEY: String = "name"

# Steam enum values used dynamically so vanilla Godot can still parse/run CI.
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
	if not _require_steam():
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
	if peers.has(peer_id):
		return
	peers[peer_id] = {
		"steam_id": steam_id,
		"display_name": display_name,
		"seat_id": -1,
		"ready": false,
	}
	peer_joined.emit(peer_id)

func unregister_peer(peer_id: int) -> void:
	if not peers.has(peer_id):
		return
	peers.erase(peer_id)
	peer_left.emit(peer_id)

func set_peer_ready(peer_id: int, ready: bool) -> void:
	if peers.has(peer_id):
		peers[peer_id]["ready"] = ready

func all_peers_ready() -> bool:
	if peers.is_empty():
		return false
	for peer: Dictionary in peers.values():
		if not peer.get("ready", false):
			return false
	return true

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

func _on_peer_connected(peer_id: int) -> void:
	register_peer(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	unregister_peer(peer_id)

func _on_steam_unavailable(reason: String) -> void:
	lobby_error.emit(reason)
	lobby_state_changed.emit(&"offline")
