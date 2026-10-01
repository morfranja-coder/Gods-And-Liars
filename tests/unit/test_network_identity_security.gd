class_name NetworkIdentitySecurityTest
extends GdUnitTestSuite

class FakeSteamPeer:
	extends RefCounted

	var steam_ids: Dictionary = {}

	func get_steam_id_for_peer_id(peer_id: int) -> int:
		return int(steam_ids.get(peer_id, -1))

func test_authenticated_steam_id_is_read_from_transport_mapping() -> void:
	var fake := FakeSteamPeer.new()
	fake.steam_ids[7] = 76561198000000007
	var resolved := int(
		NetworkManager.call(
			"_authenticated_steam_id_for_peer",
			7,
			fake,
		)
	)
	assert_int(resolved).is_equal(76561198000000007)

func test_missing_transport_mapping_fails_closed() -> void:
	var fake := RefCounted.new()
	var resolved := int(
		NetworkManager.call(
			"_authenticated_steam_id_for_peer",
			7,
			fake,
		)
	)
	assert_int(resolved).is_equal(0)
