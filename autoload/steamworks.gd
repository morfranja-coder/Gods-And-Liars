extends Node

signal steam_ready
signal steam_unavailable(reason: String)

const STEAM_APP_ID: int = 480

var initialized: bool = false
var steam_id: int = 0
var persona_name: String = ""
var lobby_id: int = 0
var _steam: Object = null

func _init() -> void:
	OS.set_environment("SteamAppId", str(STEAM_APP_ID))
	OS.set_environment("SteamGameId", str(STEAM_APP_ID))

func _ready() -> void:
	if not Engine.has_singleton("Steam"):
		mark_unavailable("GodotSteam singleton not found")
		return
	_steam = Engine.get_singleton("Steam")
	var response: Dictionary = _steam.call("steamInitEx")
	if int(response.get("status", 1)) != 0:
		mark_unavailable("Steam init failed: %s" % response)
		return
	steam_id = int(_steam.call("getSteamID"))
	persona_name = str(_steam.call("getPersonaName"))
	initialized = true
	steam_ready.emit()

func _process(_delta: float) -> void:
	if initialized and _steam != null:
		_steam.call("run_callbacks")

func get_api() -> Object:
	return _steam

func mark_ready(id: int, name: String) -> void:
	steam_id = id
	persona_name = name
	initialized = true
	steam_ready.emit()

func mark_unavailable(reason: String) -> void:
	initialized = false
	steam_unavailable.emit(reason)
