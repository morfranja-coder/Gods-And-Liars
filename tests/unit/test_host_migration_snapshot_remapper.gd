class_name HostMigrationSnapshotRemapperTest
extends GdUnitTestSuite

func test_remap_preserves_eight_players_and_tombstones_old_host() -> void:
	var snapshot := _build_snapshot()
	var remapped := HostMigrationSnapshotRemapper.remap(
		snapshot,
		{2: 1, 3: 7, 4: 8, 5: 9, 6: 10, 7: 11, 8: 12},
	)
	assert_object(remapped).is_not_null()
	assert_int(remapped.players.size()).is_equal(8)
	var old_host := _player(remapped, HostMigrationSnapshotRemapper.DISCONNECTED_HOST_PEER_ID)
	assert_bool(old_host.is_empty()).is_false()
	assert_bool(bool(old_host.get("alive", true))).is_false()
	assert_int(int(_player(remapped, 1).get("steam_id", 0))).is_equal(3002)

func test_remap_updates_vote_and_night_references() -> void:
	var remapped := HostMigrationSnapshotRemapper.remap(
		_build_snapshot(),
		{2: 1, 3: 7, 4: 8, 5: 9, 6: 10, 7: 11, 8: 12},
	)
	assert_int(int(remapped.heretic_targets[1])).is_equal(8)
	assert_int(remapped.healer_target_peer_id).is_equal(9)
	assert_int(remapped.inquisitor_target_peer_id).is_equal(10)
	assert_int(int(remapped.votes[7])).is_equal(8)

func test_remap_drops_actions_owned_by_disconnected_host() -> void:
	var snapshot := _build_snapshot()
	snapshot.heretic_targets[1] = 4
	snapshot.votes[1] = 3
	var remapped := HostMigrationSnapshotRemapper.remap(
		snapshot,
		{2: 1, 3: 7, 4: 8, 5: 9, 6: 10, 7: 11, 8: 12},
	)
	assert_bool(remapped.heretic_targets.has(HostMigrationSnapshotRemapper.DISCONNECTED_HOST_PEER_ID)).is_false()
	assert_bool(remapped.votes.has(HostMigrationSnapshotRemapper.DISCONNECTED_HOST_PEER_ID)).is_false()

func _build_snapshot() -> MatchSnapshot:
	var session := MatchSession.new(7)
	for peer_id in range(1, 9):
		session.add_player(peer_id, 3000 + peer_id, "P%d" % peer_id)
		var player := session.get_player(peer_id)
		player.seat_id = peer_id - 1
		player.role = PlayerState.Role.FAITHFUL
	session.get_player(1).role = PlayerState.Role.HERETIC
	session.get_player(2).role = PlayerState.Role.HERETIC
	session.get_player(3).role = PlayerState.Role.HEALER
	session.get_player(4).role = PlayerState.Role.INQUISITOR
	return MatchSnapshot.from_runtime(
		session,
		int(GameManager.MatchPhase.VOTING),
		3,
		12000,
		&"",
		true,
		{2: true, 3: true},
		{2: 4},
		5,
		6,
		{3: 4},
	)

func _player(snapshot: MatchSnapshot, peer_id: int) -> Dictionary:
	for data in snapshot.players:
		if int(data.get("peer_id", 0)) == peer_id:
			return data
	return {}
