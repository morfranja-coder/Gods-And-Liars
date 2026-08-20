class_name LobbyReadyTest
extends GdUnitTestSuite

func before_test() -> void:
	NetworkManager.reset()

func after_test() -> void:
	NetworkManager.reset()

func test_ready_requires_two_players() -> void:
	NetworkManager.register_peer(1, 1001, "Host")
	NetworkManager.set_peer_ready(1, true)
	assert_bool(NetworkManager.all_peers_ready()).is_false()

func test_all_players_ready_returns_true() -> void:
	NetworkManager.register_peer(1, 1001, "Host")
	NetworkManager.register_peer(2, 1002, "Guest")
	NetworkManager.set_peer_ready(1, true)
	NetworkManager.set_peer_ready(2, true)
	assert_bool(NetworkManager.all_peers_ready()).is_true()

func test_unready_player_blocks_start_gate() -> void:
	NetworkManager.register_peer(1, 1001, "Host")
	NetworkManager.register_peer(2, 1002, "Guest")
	NetworkManager.set_peer_ready(1, true)
	NetworkManager.set_peer_ready(2, false)
	assert_bool(NetworkManager.all_peers_ready()).is_false()

func test_disconnect_removes_player_from_roster() -> void:
	NetworkManager.register_peer(1, 1001, "Host")
	NetworkManager.register_peer(2, 1002, "Guest")
	NetworkManager.unregister_peer(2)
	assert_int(NetworkManager.peers.size()).is_equal(1)
	assert_bool(NetworkManager.peers.has(2)).is_false()

func test_started_lobby_rejects_ready_changes() -> void:
	NetworkManager.register_peer(1, 1001, "Host")
	NetworkManager.set_peer_ready(1, true)
	NetworkManager.lobby_started = true
	NetworkManager.set_peer_ready(1, false)
	assert_bool(bool(NetworkManager.peers[1]["ready"])).is_true()

func test_started_lobby_rejects_new_players() -> void:
	NetworkManager.register_peer(1, 1001, "Host")
	NetworkManager.lobby_started = true
	NetworkManager.register_peer(2, 1002, "Late Guest")
	assert_bool(NetworkManager.peers.has(2)).is_false()

func test_reset_clears_started_ready_and_roster_state() -> void:
	NetworkManager.register_peer(1, 1001, "Host")
	NetworkManager.register_peer(2, 1002, "Guest")
	NetworkManager.set_peer_ready(1, true)
	NetworkManager.set_peer_ready(2, true)
	NetworkManager.lobby_started = true
	NetworkManager.reset()
	assert_bool(NetworkManager.lobby_started).is_false()
	assert_bool(NetworkManager.is_host).is_false()
	assert_int(NetworkManager.lobby_id).is_equal(0)
	assert_int(NetworkManager.peers.size()).is_equal(0)

func test_same_steam_identity_can_rejoin_after_disconnect() -> void:
	NetworkManager.register_peer(2, 1002, "Guest")
	NetworkManager.unregister_peer(2)
	NetworkManager.register_peer(7, 1002, "Guest")
	assert_bool(NetworkManager.peers.has(7)).is_true()
	assert_int(int(NetworkManager.peers[7]["steam_id"])).is_equal(1002)

func test_duplicate_steam_identity_is_rejected_while_connected() -> void:
	NetworkManager.register_peer(2, 1002, "Guest")
	NetworkManager.register_peer(7, 1002, "Impostor")
	assert_bool(NetworkManager.peers.has(7)).is_false()
