class_name SeatAllocator
extends RefCounted

static func first_free_seat(peers: Dictionary, seat_count: int = TableLayout.SEAT_COUNT) -> int:
	var used: Dictionary = {}
	for peer: Dictionary in peers.values():
		var seat_id := int(peer.get("seat_id", -1))
		if seat_id >= 0 and seat_id < seat_count:
			used[seat_id] = true
	for seat_id in range(seat_count):
		if not used.has(seat_id):
			return seat_id
	return -1

static func is_valid_seat(seat_id: int, seat_count: int = TableLayout.SEAT_COUNT) -> bool:
	return seat_id >= 0 and seat_id < seat_count

static func seat_is_available(peers: Dictionary, seat_id: int, ignored_peer_id: int = -1) -> bool:
	if not is_valid_seat(seat_id):
		return false
	for raw_peer_id in peers.keys():
		var peer_id := int(raw_peer_id)
		if peer_id == ignored_peer_id:
			continue
		var peer: Dictionary = peers[raw_peer_id]
		if int(peer.get("seat_id", -1)) == seat_id:
			return false
	return true
