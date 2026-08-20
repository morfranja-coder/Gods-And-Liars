class_name NetworkSeatsTest
extends GdUnitTestSuite

func before_test() -> void:
	NetworkManager.reset()

func after_test() -> void:
	NetworkManager.reset()

func test_registered_peers_receive_unique_seats() -> void:
	NetworkManager.register_peer(1, 1001, "Host")
	NetworkManager.register_peer(2, 1002, "Guest")
	assert_int(int(NetworkManager.peers[1]["seat_id"])).is_equal(0)
	assert_int(int(NetworkManager.peers[2]["seat_id"])).is_equal(1)

func test_authoritative_seat_is_preserved() -> void:
	NetworkManager.register_peer(1, 1001, "Host", 4)
	assert_int(int(NetworkManager.peers[1]["seat_id"])).is_equal(4)
	NetworkManager.register_peer(1, 1001, "Host renamed", 2)
	assert_int(int(NetworkManager.peers[1]["seat_id"])).is_equal(4)

func test_freed_seat_can_be_reused() -> void:
	NetworkManager.register_peer(1, 1001, "Host")
	NetworkManager.register_peer(2, 1002, "Guest")
	NetworkManager.unregister_peer(1)
	NetworkManager.register_peer(3, 1003, "Replacement")
	assert_int(int(NetworkManager.peers[3]["seat_id"])).is_equal(0)

func test_duplicate_authoritative_seat_is_rejected() -> void:
	NetworkManager.register_peer(1, 1001, "Host", 2)
	NetworkManager.register_peer(2, 1002, "Guest", 2)
	assert_bool(NetworkManager.peers.has(2)).is_false()
