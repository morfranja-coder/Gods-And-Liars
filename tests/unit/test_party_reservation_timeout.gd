class_name PartyReservationTimeoutTest
extends GdUnitTestSuite

func before_test() -> void:
	NetworkManager.reset()

func after_test() -> void:
	NetworkManager.reset()

func test_reservation_deadline_is_fixed_fifteen_seconds() -> void:
	assert_int(PartyReservationPolicy.TIMEOUT_MS).is_equal(15000)
	assert_int(PartyReservationPolicy.deadline_from(2500)).is_equal(17500)

func test_reservation_expires_at_deadline_not_before() -> void:
	var deadline := PartyReservationPolicy.deadline_from(1000)
	assert_bool(PartyReservationPolicy.is_expired(deadline, deadline - 1)).is_false()
	assert_bool(PartyReservationPolicy.is_expired(deadline, deadline)).is_true()

func test_expired_tokens_are_deterministic_and_sorted() -> void:
	var deadlines := {
		9003: 3000,
		9001: 1000,
		9002: 2000,
	}
	assert_array(PartyReservationPolicy.expired_tokens(deadlines, 1999)).is_equal([9001])
	assert_array(PartyReservationPolicy.expired_tokens(deadlines, 3000)).is_equal([9001, 9002, 9003])

func test_cleanup_releases_slots_and_removes_partial_party_member() -> void:
	NetworkManager.register_peer(1, 1001, "Host")
	NetworkManager.register_peer(2, 1002, "Partial Party")
	NetworkManager.set("_party_reservations", {9001: 2})
	NetworkManager.set("_party_reservation_deadlines", {9001: 5000})
	NetworkManager.set("_peer_party_tokens", {2: 9001})
	assert_int(NetworkManager.advertised_open_slots()).is_equal(4)
	assert_int(int(NetworkManager.call("_cleanup_expired_party_reservations", 4999))).is_equal(0)
	assert_bool(NetworkManager.peers.has(2)).is_true()
	assert_int(int(NetworkManager.call("_cleanup_expired_party_reservations", 5000))).is_equal(1)
	assert_bool(NetworkManager.peers.has(2)).is_false()
	assert_int(NetworkManager.advertised_open_slots()).is_equal(7)
	var expired: Dictionary = NetworkManager.get("_expired_party_tokens")
	assert_bool(expired.has(9001)).is_true()

func test_reset_clears_reservation_deadlines_and_expired_tokens() -> void:
	NetworkManager.set("_party_reservations", {9001: 2})
	NetworkManager.set("_party_reservation_deadlines", {9001: 5000})
	NetworkManager.set("_expired_party_tokens", {9002: true})
	NetworkManager.reset()
	var reservations: Dictionary = NetworkManager.get("_party_reservations")
	var deadlines: Dictionary = NetworkManager.get("_party_reservation_deadlines")
	var expired: Dictionary = NetworkManager.get("_expired_party_tokens")
	assert_bool(reservations.is_empty()).is_true()
	assert_bool(deadlines.is_empty()).is_true()
	assert_bool(expired.is_empty()).is_true()
