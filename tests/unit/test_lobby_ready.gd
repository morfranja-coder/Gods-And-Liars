class_name LobbyReadyTest
extends GdUnitTestSuite

func before_test() -> void:
	NetworkManager.reset()

func after_test() -> void:
	NetworkManager.reset()

func test_steam_lobby_filters_use_equal_and_worldwide() -> void:
	assert_int(NetworkManager.STEAM_LOBBY_COMPARISON_EQUAL).is_equal(0)
	assert_int(NetworkManager.STEAM_LOBBY_DISTANCE_WORLDWIDE).is_equal(3)

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

func test_host_start_is_false_without_active_lobby() -> void:
	NetworkManager.is_host = true
	for peer_id in range(1, 9):
		NetworkManager.register_peer(peer_id, 4000 + peer_id, "P%d" % peer_id)
		NetworkManager.set_peer_ready(peer_id, true)
	assert_int(NetworkManager.lobby_id).is_equal(0)
	assert_bool(NetworkManager.can_host_start()).is_false()

func test_local_ready_is_false_without_active_lobby() -> void:
	NetworkManager.register_peer(1, 5001, "Host")
	NetworkManager.set_peer_ready(1, true)
	assert_int(NetworkManager.lobby_id).is_equal(0)
	assert_bool(NetworkManager.local_peer_ready()).is_false()

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

func test_anchor_party_reservations_are_removed_from_advertised_slots() -> void:
	NetworkManager.register_peer(1, 1001, "Host")
	var reserved_ids: Array[int] = [1002, 1003, 1004, 1005]
	NetworkManager.set("_reserved_party_steam_ids", reserved_ids)
	assert_int(NetworkManager.advertised_open_slots()).is_equal(3)

func test_anchor_party_reservation_is_consumed_as_members_register() -> void:
	NetworkManager.register_peer(1, 1001, "Host")
	var reserved_ids: Array[int] = [1002, 1003, 1004]
	NetworkManager.set("_reserved_party_steam_ids", reserved_ids)
	assert_int(NetworkManager.advertised_open_slots()).is_equal(4)
	NetworkManager.register_peer(2, 1002, "Friend")
	assert_int(NetworkManager.advertised_open_slots()).is_equal(4)
	var remaining: Array[int] = NetworkManager.get("_reserved_party_steam_ids")
	assert_int(remaining.size()).is_equal(2)
	assert_bool(remaining.has(1002)).is_false()

func test_external_party_reservation_prevents_slot_theft_while_members_join() -> void:
	for peer_id in range(1, 7):
		NetworkManager.register_peer(peer_id, 2000 + peer_id, "P%d" % peer_id)
	NetworkManager.set("_party_reservations", {9001: 2})
	assert_int(NetworkManager.advertised_open_slots()).is_equal(0)

func test_full_roster_never_advertises_negative_capacity() -> void:
	for peer_id in range(1, 9):
		NetworkManager.register_peer(peer_id, 3000 + peer_id, "P%d" % peer_id)
	NetworkManager.set("_party_reservations", {9002: 3})
	assert_int(NetworkManager.advertised_open_slots()).is_equal(0)
