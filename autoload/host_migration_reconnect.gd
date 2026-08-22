extends Node

signal reconnect_started(host_steam_id: int)
signal reconnect_identity_restored(old_peer_id: int, new_peer_id: int, steam_id: int)
signal reconnect_failed(reason: String)

const TRANSPORT_READY_KEY := "migration_transport_ready"
const POLL_INTERVAL_MS := 200

var reconnect_active: bool = false
var old_to_new_peer_ids: Dictionary = {}
var _last_poll_ms: int = 0
var _client_attempted: bool = false

func _ready() -> void:
	HostMigrationManager.host_loss_detected.connect(_on_host_loss_detected)
	HostMigrationTransport.migrated_host_transport_ready.connect(_on_host_transport_ready)
	multiplayer.connected_to_server.connect(_on_connected_to_migrated_host)
	NetworkManager.lobby_state_changed.connect(_on_lobby_state_changed)

func _process(_delta: float) -> void:
	if not reconnect_active or NetworkManager.is_host or _client_attempted:
		return
	var now_ms := Time.get_ticks_msec()
	if now_ms - _last_poll_ms < POLL_INTERVAL_MS:
		return
	_last_poll_ms = now_ms
	_try_begin_client_reconnect()

func reset() -> void:
	reconnect_active = false
	old_to_new_peer_ids.clear()
	_last_poll_ms = 0
	_client_attempted = false

func _on_host_loss_detected(_backup_steam_id: int) -> void:
	reconnect_active = true
	old_to_new_peer_ids.clear()
	_last_poll_ms = 0
	_client_attempted = false

func _on_host_transport_ready(_steam_id: int) -> void:
	if not HostMigrationManager.has_valid_backup_snapshot():
		_fail("Migrated host has no valid snapshot for reconnect mapping.")
		return
	var old_peer_id := HostMigrationReconnectRules.old_peer_id_for_steam_id(
		HostMigrationManager.backup_snapshot,
		Steamworks.steam_id,
	)
	if old_peer_id <= 0:
		_fail("Migrated host identity is missing from the snapshot.")
		return
	_rekey_roster_peer(old_peer_id, 1, Steamworks.steam_id)
	_publish_transport_ready()
	reconnect_active = true

func _publish_transport_ready() -> void:
	var steam := Steamworks.get_api()
	if steam == null or NetworkManager.lobby_id <= 0:
		_fail("Steam lobby is unavailable while publishing migrated transport.")
		return
	steam.call(
		"setLobbyData",
		NetworkManager.lobby_id,
		TRANSPORT_READY_KEY,
		str(Steamworks.steam_id),
	)
	NetworkManager.lobby_state_changed.emit(&"host_migration_reconnecting")

func _try_begin_client_reconnect() -> void:
	var steam := Steamworks.get_api()
	if steam == null or NetworkManager.lobby_id <= 0:
		return
	var ready_owner := int(
		str(steam.call("getLobbyData", NetworkManager.lobby_id, TRANSPORT_READY_KEY))
	)
	if not HostMigrationReconnectRules.can_attempt_client_reconnect(
		NetworkManager.lobby_id,
		Steamworks.steam_id,
		HostMigrationManager.backup_authority_steam_id,
		ready_owner,
		multiplayer.multiplayer_peer != null,
	):
		return
	if not ClassDB.class_exists("SteamMultiplayerPeer"):
		_fail("SteamMultiplayerPeer is unavailable for migrated client reconnect.")
		return
	var peer = ClassDB.instantiate("SteamMultiplayerPeer")
	if peer == null:
		_fail("Could not instantiate SteamMultiplayerPeer for migrated client reconnect.")
		return
	var create_result = peer.call(
		"create_client",
		HostMigrationManager.backup_authority_steam_id,
		0,
	)
	if create_result != null and int(create_result) != OK:
		_fail("Migrated client reconnect failed to start (error %s)." % create_result)
		return
	peer.set("server_relay", true)
	multiplayer.multiplayer_peer = peer
	_client_attempted = true
	reconnect_started.emit(HostMigrationManager.backup_authority_steam_id)
	NetworkManager.lobby_state_changed.emit(&"host_migration_client_connecting")

func _on_connected_to_migrated_host() -> void:
	if not reconnect_active or NetworkManager.is_host:
		return
	_announce_migrated_identity.rpc_id(
		1,
		Steamworks.steam_id,
		Steamworks.persona_name,
	)

@rpc("any_peer", "reliable")
func _announce_migrated_identity(client_steam_id: int, display_name: String) -> void:
	if not NetworkManager.is_host or not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	var snapshot := HostMigrationManager.backup_snapshot
	var old_peer_id := HostMigrationReconnectRules.old_peer_id_for_steam_id(
		snapshot,
		client_steam_id,
	)
	if old_peer_id <= 0 or old_peer_id == HostMigrationReconnectRules.OLD_HOST_PEER_ID:
		return
	var expected_data := _snapshot_player_data(snapshot, client_steam_id)
	if expected_data.is_empty():
		return
	if IdentityPolicy.sanitize_display_name(display_name) != str(expected_data.get("display_name", "")):
		return
	_rekey_roster_peer(old_peer_id, sender_id, client_steam_id)

func _snapshot_player_data(snapshot: MatchSnapshot, steam_id: int) -> Dictionary:
	if snapshot == null:
		return {}
	for data in snapshot.players:
		if int(data.get("steam_id", 0)) == steam_id:
			return data
	return {}

func _rekey_roster_peer(old_peer_id: int, new_peer_id: int, steam_id: int) -> void:
	var snapshot_data := _snapshot_player_data(HostMigrationManager.backup_snapshot, steam_id)
	if snapshot_data.is_empty():
		return
	NetworkManager.peers.erase(old_peer_id)
	NetworkManager.peers[new_peer_id] = LobbyRules.make_peer(
		steam_id,
		str(snapshot_data.get("display_name", "")),
		bool(snapshot_data.get("ready", true)),
		int(snapshot_data.get("seat_id", -1)),
	)
	old_to_new_peer_ids[old_peer_id] = new_peer_id
	NetworkManager.peer_updated.emit(new_peer_id)
	reconnect_identity_restored.emit(old_peer_id, new_peer_id, steam_id)

func _fail(reason: String) -> void:
	reconnect_failed.emit(reason)
	NetworkManager.lobby_state_changed.emit(&"host_migration_reconnect_failed")

func _on_lobby_state_changed(state: StringName) -> void:
	if state in [&"steam_ready", &"offline"]:
		reset()
