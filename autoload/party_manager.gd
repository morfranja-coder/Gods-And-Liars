extends Node

signal party_changed
signal party_error(message: String)
signal party_lobby_state_changed(state_name: StringName)

const GAME_TAG_KEY := "game"
const GAME_TAG_VALUE := "GodsAndLiarsMVP"
const LOBBY_KIND_KEY := "kind"
const LOBBY_KIND_PARTY := "party"
const MEMBER_NAME_KEY := "display_name"
const STEAM_LOBBY_TYPE_FRIENDS_ONLY := 1
const STEAM_RESULT_OK := 1
const STEAM_CHAT_ENTER_SUCCESS := 1

var state := PartyState.new()
var party_lobby_id: int = 0
var _steam: Object = null
var _pending_create: bool = false
var _pending_join_id: int = 0

func _ready() -> void:
	Steamworks.steam_ready.connect(_bind_steam_callbacks)
	Steamworks.steam_unavailable.connect(_on_steam_unavailable)
	if Steamworks.initialized:
		_bind_steam_callbacks()

func _bind_steam_callbacks() -> void:
	_steam = Steamworks.get_api()
	if _steam == null:
		return
	_connect_steam_signal("lobby_created", _on_lobby_created)
	_connect_steam_signal("lobby_joined", _on_lobby_joined)
	_connect_steam_signal("lobby_chat_update", _on_lobby_chat_update)
	_connect_steam_signal("join_requested", _on_join_requested)
	_reset_from_local_identity()

func _connect_steam_signal(signal_name: StringName, method: Callable) -> void:
	if _steam.has_signal(signal_name) and not _steam.is_connected(signal_name, method):
		_steam.connect(signal_name, method)

func reset_to_solo() -> void:
	party_lobby_id = 0
	_pending_create = false
	_pending_join_id = 0
	if not Steamworks.initialized or Steamworks.steam_id <= 0:
		state = PartyState.new()
		party_changed.emit()
		return
	state.reset_to_solo(Steamworks.steam_id, Steamworks.persona_name)
	party_changed.emit()

func ensure_party_lobby() -> bool:
	if party_lobby_id != 0:
		return true
	if _pending_create:
		return false
	if not _require_steam():
		return false
	_pending_create = true
	party_lobby_state_changed.emit(&"creating")
	_steam.call(
		"createLobby",
		STEAM_LOBBY_TYPE_FRIENDS_ONLY,
		QuickMatchRules.MAX_PARTY_SIZE,
	)
	return false

func join_party_lobby(target_lobby_id: int) -> bool:
	if target_lobby_id <= 0 or not _require_steam():
		return false
	if party_lobby_id == target_lobby_id:
		return true
	if party_lobby_id != 0:
		party_error.emit("Salí del grupo actual antes de unirte a otro.")
		return false
	_pending_join_id = target_lobby_id
	party_lobby_state_changed.emit(&"joining")
	_steam.call("joinLobby", target_lobby_id)
	return true

func leave_party() -> void:
	if _steam != null and party_lobby_id != 0:
		_steam.call("leaveLobby", party_lobby_id)
	reset_to_solo()
	party_lobby_state_changed.emit(&"solo")

func open_invite_overlay() -> bool:
	if party_lobby_id == 0:
		ensure_party_lobby()
		party_error.emit("El grupo se está preparando. Volvé a pulsar Invitar cuando esté listo.")
		return false
	if _steam == null or not _steam.has_method("activateGameOverlayInviteDialog"):
		party_error.emit("La interfaz de invitación de Steam no está disponible.")
		return false
	_steam.call("activateGameOverlayInviteDialog", party_lobby_id)
	return true

func apply_snapshot(party_id: int, leader_steam_id: int, members: Dictionary) -> bool:
	var next_state := PartyState.new()
	if not next_state.set_snapshot(party_id, leader_steam_id, members):
		party_error.emit("Party snapshot inválido.")
		return false
	if Steamworks.initialized and not next_state.members.has(Steamworks.steam_id):
		party_error.emit("El Party snapshot no contiene al jugador local.")
		return false
	state = next_state
	party_lobby_id = party_id
	party_changed.emit()
	return true

func size() -> int:
	return state.size()

func slots_available() -> int:
	return state.slots_available()

func is_local_leader() -> bool:
	return Steamworks.initialized and state.is_leader(Steamworks.steam_id)

func can_queue() -> bool:
	return state.can_queue() and is_local_leader()

func member_ids() -> Array[int]:
	return state.member_ids()

func _require_steam() -> bool:
	if not Steamworks.initialized or _steam == null:
		party_error.emit("Steam no está disponible para administrar el grupo.")
		return false
	return true

func _refresh_from_steam_lobby() -> void:
	if _steam == null or party_lobby_id == 0:
		return
	var owner_id := int(_steam.call("getLobbyOwner", party_lobby_id))
	var member_count := int(_steam.call("getNumLobbyMembers", party_lobby_id))
	var members: Dictionary = {}
	for index in range(member_count):
		var member_id := int(_steam.call("getLobbyMemberByIndex", party_lobby_id, index))
		if member_id <= 0:
			continue
		var display_name := str(
			_steam.call("getLobbyMemberData", party_lobby_id, member_id, MEMBER_NAME_KEY)
		)
		if display_name.is_empty() and member_id == Steamworks.steam_id:
			display_name = Steamworks.persona_name
		elif display_name.is_empty() and _steam.has_method("getFriendPersonaName"):
			display_name = str(_steam.call("getFriendPersonaName", member_id))
		if display_name.is_empty():
			display_name = "Steam %s" % member_id
		members[member_id] = IdentityPolicy.sanitize_display_name(display_name)
	if not apply_snapshot(party_lobby_id, owner_id, members):
		party_error.emit("No se pudo sincronizar el Party Lobby de Steam.")

func _publish_local_member_data() -> void:
	if _steam == null or party_lobby_id == 0:
		return
	_steam.call("setLobbyMemberData", party_lobby_id, MEMBER_NAME_KEY, Steamworks.persona_name)

func _on_lobby_created(result: int, new_lobby_id: int) -> void:
	if not _pending_create:
		return
	_pending_create = false
	if result != STEAM_RESULT_OK:
		party_error.emit("Steam no pudo crear el grupo (resultado %s)." % result)
		party_lobby_state_changed.emit(&"solo")
		return
	party_lobby_id = new_lobby_id
	_steam.call("setLobbyData", new_lobby_id, GAME_TAG_KEY, GAME_TAG_VALUE)
	_steam.call("setLobbyData", new_lobby_id, LOBBY_KIND_KEY, LOBBY_KIND_PARTY)
	_publish_local_member_data()
	_refresh_from_steam_lobby()
	party_lobby_state_changed.emit(&"ready")

func _on_lobby_joined(joined_lobby_id: int, _permissions: int, _locked, response: int) -> void:
	if joined_lobby_id != _pending_join_id:
		return
	_pending_join_id = 0
	if response != STEAM_CHAT_ENTER_SUCCESS:
		party_error.emit(
			"Steam no pudo unir el grupo %s (respuesta %s)." % [joined_lobby_id, response]
		)
		party_lobby_state_changed.emit(&"solo")
		return
	party_lobby_id = joined_lobby_id
	_publish_local_member_data()
	_refresh_from_steam_lobby()
	party_lobby_state_changed.emit(&"ready")

func _on_lobby_chat_update(
	updated_lobby_id: int,
	_changed_user_id: int,
	_making_change_user_id: int,
	_chat_state: int,
) -> void:
	if updated_lobby_id != party_lobby_id:
		return
	_refresh_from_steam_lobby()

func _on_join_requested(requested_lobby_id: int, _friend_id: int) -> void:
	if _steam == null or requested_lobby_id <= 0:
		return
	var lobby_kind := str(_steam.call("getLobbyData", requested_lobby_id, LOBBY_KIND_KEY))
	if lobby_kind != LOBBY_KIND_PARTY:
		return
	join_party_lobby(requested_lobby_id)

func _reset_from_local_identity() -> void:
	if party_lobby_id == 0:
		reset_to_solo()

func _on_steam_unavailable(_reason: String) -> void:
	_steam = null
	state = PartyState.new()
	party_lobby_id = 0
	_pending_create = false
	_pending_join_id = 0
	party_changed.emit()
	party_lobby_state_changed.emit(&"offline")
