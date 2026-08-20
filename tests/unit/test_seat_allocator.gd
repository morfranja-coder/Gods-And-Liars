class_name SeatAllocatorTest
extends GdUnitTestSuite

func test_first_peer_gets_seat_zero() -> void:
	assert_int(SeatAllocator.first_free_seat({})).is_equal(0)

func test_allocator_skips_used_seats() -> void:
	var peers := {
		1: LobbyRules.make_peer(1001, "Host", false, 0),
		2: LobbyRules.make_peer(1002, "Guest", false, 2),
	}
	assert_int(SeatAllocator.first_free_seat(peers)).is_equal(1)

func test_allocator_returns_minus_one_when_full() -> void:
	var peers := {}
	for seat_id in range(TableLayout.SEAT_COUNT):
		peers[seat_id + 1] = LobbyRules.make_peer(1000 + seat_id, "P%s" % seat_id, false, seat_id)
	assert_int(SeatAllocator.first_free_seat(peers)).is_equal(-1)

func test_seat_availability_ignores_current_peer() -> void:
	var peers := {1: LobbyRules.make_peer(1001, "Host", false, 3)}
	assert_bool(SeatAllocator.seat_is_available(peers, 3)).is_false()
	assert_bool(SeatAllocator.seat_is_available(peers, 3, 1)).is_true()
