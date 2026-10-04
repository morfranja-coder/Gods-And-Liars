class_name NetworkProtocolJoinValidationTest
extends GdUnitTestSuite

class FakeSteam:
	extends RefCounted

	var lobby_protocols: Dictionary = {}
	var requested_lobbies: Array[int] = []
	var joined_lobbies: Array[int] = []
	var request_result := true

	func getLobbyData(lobby_id: int, key: String) -> String:
		if key != MatchProtocolRules.PROTOCOL_VERSION_KEY:
			return ""
		return str(lobby_protocols.get(lobby_id, ""))

	func requestLobbyData(lobby_id: int) -> bool:
		requested_lobbies.append(lobby_id)
		return request_result

	func joinLobby(lobby_id: int) -> void:
		joined_lobbies.append(lobby_id)


func before_test() -> void:
	NetworkManager.reset()
	NetworkManager.set("_steam", null)


func after_test() -> void:
	NetworkManager.reset()
	NetworkManager.set("_steam", null)


func test_cached_compatible_protocol_joins_immediately() -> void:
	var fake := FakeSteam.new()
	fake.lobby_protocols[101] = MatchProtocolRules.protocol_value()
	NetworkManager.set("_steam", fake)

	NetworkManager.call("_begin_join_protocol_validation", 101)

	assert_int(fake.requested_lobbies.size()).is_equal(0)
	assert_int(fake.joined_lobbies.size()).is_equal(1)
	assert_int(fake.joined_lobbies[0]).is_equal(101)
	assert_int(int(NetworkManager.get("_pending_join_match_id"))).is_equal(101)
	assert_int(int(NetworkManager.get("_pending_protocol_lobby_id"))).is_equal(0)


func test_missing_cached_protocol_requests_metadata_before_join() -> void:
	var fake := FakeSteam.new()
	NetworkManager.set("_steam", fake)

	NetworkManager.call("_begin_join_protocol_validation", 202)

	assert_int(fake.requested_lobbies.size()).is_equal(1)
	assert_int(fake.requested_lobbies[0]).is_equal(202)
	assert_int(fake.joined_lobbies.size()).is_equal(0)
	assert_int(int(NetworkManager.get("_pending_protocol_lobby_id"))).is_equal(202)
	assert_int(int(NetworkManager.get("_pending_join_match_id"))).is_equal(0)


func test_requested_compatible_metadata_continues_join() -> void:
	var fake := FakeSteam.new()
	NetworkManager.set("_steam", fake)
	NetworkManager.call("_begin_join_protocol_validation", 303)
	fake.lobby_protocols[303] = MatchProtocolRules.protocol_value()

	NetworkManager.call("_on_lobby_data_update", true, 303, 303)

	assert_int(fake.joined_lobbies.size()).is_equal(1)
	assert_int(fake.joined_lobbies[0]).is_equal(303)
	assert_int(int(NetworkManager.get("_pending_protocol_lobby_id"))).is_equal(0)
	assert_int(int(NetworkManager.get("_pending_join_match_id"))).is_equal(303)


func test_requested_incompatible_metadata_fails_closed() -> void:
	var fake := FakeSteam.new()
	NetworkManager.set("_steam", fake)
	NetworkManager.call("_begin_join_protocol_validation", 404)
	fake.lobby_protocols[404] = "999"

	NetworkManager.call("_on_lobby_data_update", true, 404, 404)

	assert_int(fake.joined_lobbies.size()).is_equal(0)
	assert_int(int(NetworkManager.get("_pending_protocol_lobby_id"))).is_equal(0)
	assert_int(int(NetworkManager.get("_pending_join_match_id"))).is_equal(0)


func test_failed_metadata_request_never_joins() -> void:
	var fake := FakeSteam.new()
	fake.request_result = false
	NetworkManager.set("_steam", fake)

	NetworkManager.call("_begin_join_protocol_validation", 505)

	assert_int(fake.requested_lobbies.size()).is_equal(1)
	assert_int(fake.joined_lobbies.size()).is_equal(0)
	assert_int(int(NetworkManager.get("_pending_protocol_lobby_id"))).is_equal(0)
	assert_int(int(NetworkManager.get("_pending_join_match_id"))).is_equal(0)


func test_unrelated_lobby_update_does_not_release_pending_join() -> void:
	var fake := FakeSteam.new()
	NetworkManager.set("_steam", fake)
	NetworkManager.call("_begin_join_protocol_validation", 606)
	fake.lobby_protocols[606] = MatchProtocolRules.protocol_value()

	NetworkManager.call("_on_lobby_data_update", true, 999, 999)

	assert_int(fake.joined_lobbies.size()).is_equal(0)
	assert_int(int(NetworkManager.get("_pending_protocol_lobby_id"))).is_equal(606)


func test_callback_argument_orders_are_normalized() -> void:
	var success_first: Dictionary = NetworkManager.call(
		"_normalize_lobby_data_update",
		true,
		707,
		707,
	)
	var success_last: Dictionary = NetworkManager.call(
		"_normalize_lobby_data_update",
		808,
		808,
		true,
	)

	assert_bool(bool(success_first.get("success", false))).is_true()
	assert_int(int(success_first.get("lobby_id", 0))).is_equal(707)
	assert_bool(bool(success_last.get("success", false))).is_true()
	assert_int(int(success_last.get("lobby_id", 0))).is_equal(808)
