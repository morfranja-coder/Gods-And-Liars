class_name HostMigrationManagerTest
extends GdUnitTestSuite

var _original_steam_id: int = 0

func before_test() -> void:
	_original_steam_id = Steamworks.steam_id
	HostMigrationManager.reset()

func after_test() -> void:
	Steamworks.steam_id = _original_steam_id
	HostMigrationManager.reset()

func test_non_intended_client_ignores_valid_backup_snapshot() -> void:
	Steamworks.steam_id = 5002
	var snapshot := _build_snapshot()
	HostMigrationManager.call(
		"_receive_backup_snapshot",
		5003,
		1,
		snapshot.to_json(),
	)
	assert_bool(HostMigrationManager.has_valid_backup_snapshot()).is_false()
	assert_int(HostMigrationManager.backup_sequence).is_equal(0)

func test_intended_client_accepts_newer_valid_backup_snapshot() -> void:
	Steamworks.steam_id = 5002
	var snapshot := _build_snapshot()
	HostMigrationManager.call(
		"_receive_backup_snapshot",
		5002,
		1,
		snapshot.to_json(),
	)
	assert_bool(HostMigrationManager.has_valid_backup_snapshot()).is_true()
	assert_int(HostMigrationManager.backup_sequence).is_equal(1)
	assert_int(HostMigrationManager.backup_snapshot.round_number).is_equal(2)

func test_stale_backup_sequence_is_ignored() -> void:
	Steamworks.steam_id = 5002
	var snapshot := _build_snapshot()
	HostMigrationManager.call("_receive_backup_snapshot", 5002, 2, snapshot.to_json())
	HostMigrationManager.call("_receive_backup_snapshot", 5002, 1, snapshot.to_json())
	assert_int(HostMigrationManager.backup_sequence).is_equal(2)

func _build_snapshot() -> MatchSnapshot:
	var session := MatchSession.new(1234)
	for peer_id in range(1, 9):
		session.add_player(peer_id, 5000 + peer_id, "P%d" % peer_id)
		var player := session.get_player(peer_id)
		player.role = PlayerState.Role.FAITHFUL
		player.ready = true
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
