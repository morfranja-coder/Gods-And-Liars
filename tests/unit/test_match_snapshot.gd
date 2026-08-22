class_name MatchSnapshotTest
extends GdUnitTestSuite

func test_snapshot_round_trip_preserves_authoritative_state() -> void:
	var session := _build_session()
	var snapshot := MatchSnapshot.from_runtime(
		session,
		int(GameManager.MatchPhase.VOTING),
		3,
		12500,
		&"",
		true,
		{1: true, 2: true, 3: true},
		{1: 4, 2: 5},
		6,
		7,
		{1: 4, 2: 4, 3: 5},
	)
	assert_object(snapshot).is_not_null()
	var restored := MatchSnapshot.from_json(snapshot.to_json())
	assert_object(restored).is_not_null()
	assert_int(restored.version).is_equal(MatchSnapshot.VERSION)
	assert_int(restored.phase).is_equal(int(GameManager.MatchPhase.VOTING))
	assert_int(restored.round_number).is_equal(3)
	assert_int(restored.phase_remaining_ms).is_equal(12500)
	assert_bool(restored.roles_dispatched).is_true()
	assert_int(int(restored.heretic_targets[1])).is_equal(4)
	assert_int(int(restored.votes[3])).is_equal(5)
	assert_bool(bool(restored.role_acknowledged[2])).is_true()

func test_restore_session_preserves_secret_roles_and_player_state() -> void:
	var session := _build_session()
	var snapshot := MatchSnapshot.from_runtime(
		session,
		int(GameManager.MatchPhase.DAY_DISCUSSION),
		2,
		42000,
		&"",
		true,
		{},
		{},
		0,
		0,
		{},
	)
	var restored_session := snapshot.restore_session()
	assert_object(restored_session).is_not_null()
	assert_int(restored_session.players.size()).is_equal(8)
	var restored_player := restored_session.get_player(2)
	assert_object(restored_player).is_not_null()
	assert_int(int(restored_player.role)).is_equal(int(PlayerState.Role.HERETIC))
	assert_bool(restored_player.alive).is_false()
	assert_int(restored_player.seat_id).is_equal(1)
	assert_int(restored_player.selected_target_peer_id).is_equal(8)

func test_snapshot_rejects_wrong_version() -> void:
	var snapshot := MatchSnapshot.from_runtime(
		_build_session(),
		int(GameManager.MatchPhase.NIGHT_START),
		1,
		1000,
		&"",
		true,
		{},
		{},
		0,
		0,
		{},
	)
	var data := snapshot.to_dictionary()
	data["version"] = MatchSnapshot.VERSION + 1
	assert_object(MatchSnapshot.from_dictionary(data)).is_null()

func test_snapshot_rejects_duplicate_seats() -> void:
	var snapshot := MatchSnapshot.from_runtime(
		_build_session(),
		int(GameManager.MatchPhase.NIGHT_START),
		1,
		1000,
		&"",
		true,
		{},
		{},
		0,
		0,
		{},
	)
	var data := snapshot.to_dictionary()
	var players: Array = data["players"]
	players[1]["seat_id"] = players[0]["seat_id"]
	assert_object(MatchSnapshot.from_dictionary(data)).is_null()

func test_snapshot_rejects_non_eight_player_session() -> void:
	var session := MatchSession.new()
	for peer_id in range(1, 8):
		session.add_player(peer_id, 4000 + peer_id, "P%d" % peer_id)
	assert_object(
		MatchSnapshot.from_runtime(
			session,
			int(GameManager.MatchPhase.READY),
			0,
			0,
			&"",
			false,
			{},
			{},
			0,
			0,
			{},
		)
	).is_null()

func _build_session() -> MatchSession:
	var session := MatchSession.new(1234)
	for peer_id in range(1, 9):
		assert_bool(session.add_player(peer_id, 3000 + peer_id, "P%d" % peer_id)).is_true()
		var player := session.get_player(peer_id)
		player.ready = true
		player.role = PlayerState.Role.FAITHFUL
	player_role(session, 1, PlayerState.Role.HERETIC)
	player_role(session, 2, PlayerState.Role.HERETIC)
	player_role(session, 3, PlayerState.Role.HEALER)
	player_role(session, 4, PlayerState.Role.INQUISITOR)
	var player_two := session.get_player(2)
	player_two.alive = false
	player_two.selected_target_peer_id = 8
	player_two.vote_target_peer_id = 5
	return session

func player_role(session: MatchSession, peer_id: int, role: PlayerState.Role) -> void:
	var player := session.get_player(peer_id)
	player.role = role
