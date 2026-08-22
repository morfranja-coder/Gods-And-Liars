class_name HostMigrationReconnectRulesTest
extends GdUnitTestSuite

func test_client_can_reconnect_only_to_ready_backup_owner() -> void:
	assert_bool(
		HostMigrationReconnectRules.can_attempt_client_reconnect(
			7001,
			1003,
			1002,
			1002,
			false,
		)
	).is_true()

func test_backup_does_not_reconnect_as_client() -> void:
	assert_bool(
		HostMigrationReconnectRules.can_attempt_client_reconnect(
			7001,
			1002,
			1002,
			1002,
			false,
		)
	).is_false()

func test_wrong_ready_owner_blocks_reconnect() -> void:
	assert_bool(
		HostMigrationReconnectRules.can_attempt_client_reconnect(
			7001,
			1003,
			1002,
			1004,
			false,
		)
	).is_false()

func test_existing_peer_blocks_duplicate_reconnect() -> void:
	assert_bool(
		HostMigrationReconnectRules.can_attempt_client_reconnect(
			7001,
			1003,
			1002,
			1002,
			true,
		)
	).is_false()

func test_old_peer_lookup_uses_stable_steam_identity() -> void:
	var snapshot := _snapshot()
	assert_int(
		HostMigrationReconnectRules.old_peer_id_for_steam_id(snapshot, 4005)
	).is_equal(5)
	assert_int(
		HostMigrationReconnectRules.old_peer_id_for_steam_id(snapshot, 9999)
	).is_equal(0)

func test_expected_remaining_players_excludes_lost_host() -> void:
	assert_int(
		HostMigrationReconnectRules.expected_remaining_players(_snapshot())
	).is_equal(7)

func _snapshot() -> MatchSnapshot:
	var session := MatchSession.new()
	for peer_id in range(1, 9):
		session.add_player(peer_id, 4000 + peer_id, "P%d" % peer_id)
		var player := session.get_player(peer_id)
		player.seat_id = peer_id - 1
		player.role = PlayerState.Role.FAITHFUL
	return MatchSnapshot.from_runtime(
		session,
		int(GameManager.MatchPhase.DAY_DISCUSSION),
		2,
		30000,
		&"",
		true,
		{},
		{},
		0,
		0,
		{},
	)
