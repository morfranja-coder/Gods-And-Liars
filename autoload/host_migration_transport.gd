extends Node

signal migrated_host_transport_ready(steam_id: int)
signal migrated_host_transport_failed(reason: String)

var promotion_attempted: bool = false

func _ready() -> void:
	HostMigrationManager.host_loss_promotion_ready.connect(_on_host_loss_promotion_ready)
	NetworkManager.lobby_state_changed.connect(_on_lobby_state_changed)

func reset() -> void:
	promotion_attempted = false

func _on_host_loss_promotion_ready(backup_steam_id: int) -> void:
	if promotion_attempted:
		return
	promotion_attempted = true
	var steam := Steamworks.get_api()
	if steam == null:
		_fail("Steam API is unavailable during host promotion.")
		return
	var observed_owner := int(steam.call("getLobbyOwner", NetworkManager.lobby_id))
	if not HostTransportPromotionRules.can_promote(
		NetworkManager.lobby_id,
		Steamworks.steam_id,
		backup_steam_id,
		observed_owner,
		HostMigrationManager.has_valid_backup_snapshot(),
		multiplayer.multiplayer_peer != null,
	):
		_fail("Host promotion prerequisites are no longer valid.")
		return
	if not ClassDB.class_exists("SteamMultiplayerPeer"):
		_fail("SteamMultiplayerPeer is unavailable in this Godot build.")
		return
	var peer = ClassDB.instantiate("SteamMultiplayerPeer")
	if peer == null:
		_fail("Could not instantiate SteamMultiplayerPeer for migration.")
		return
	var create_result = peer.call("create_host", 0)
	if create_result != null and int(create_result) != OK:
		_fail("Migrated host transport creation failed (error %s)." % create_result)
		return
	peer.set("server_relay", true)
	multiplayer.multiplayer_peer = peer
	NetworkManager.is_host = true
	NetworkManager.lobby_started = true
	NetworkManager.lobby_state_changed.emit(&"host_migration_transport_ready")
	migrated_host_transport_ready.emit(Steamworks.steam_id)

func _fail(reason: String) -> void:
	NetworkManager.is_host = false
	NetworkManager.lobby_state_changed.emit(&"host_migration_transport_failed")
	migrated_host_transport_failed.emit(reason)

func _on_lobby_state_changed(state: StringName) -> void:
	if state in [&"steam_ready", &"offline", &"connection_failed"]:
		reset()
