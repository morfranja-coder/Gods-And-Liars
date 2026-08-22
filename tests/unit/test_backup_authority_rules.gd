class_name BackupAuthorityRulesTest
extends GdUnitTestSuite

func test_keeps_existing_backup_while_connected_even_if_dead() -> void:
	var roster := {
		1: {"steam_id": 9000},
		2: {"steam_id": 1002},
		3: {"steam_id": 1003},
	}
	var alive := {1: true, 2: false, 3: true}
	assert_int(
		BackupAuthorityRules.keep_or_choose_backup(roster, alive, 9000, 1002)
	).is_equal(1002)

func test_rechooses_when_existing_backup_disconnects() -> void:
	var roster := {
		1: {"steam_id": 9000},
		3: {"steam_id": 1003},
		4: {"steam_id": 1004},
	}
	var alive := {1: true, 3: true, 4: true}
	assert_int(
		BackupAuthorityRules.keep_or_choose_backup(roster, alive, 9000, 1002)
	).is_equal(1003)

func test_initial_backup_uses_successor_rule() -> void:
	var roster := {
		1: {"steam_id": 9000},
		2: {"steam_id": 2002},
		3: {"steam_id": 1003},
	}
	var alive := {1: true, 2: true, 3: true}
	assert_int(
		BackupAuthorityRules.keep_or_choose_backup(roster, alive, 9000, 0)
	).is_equal(1003)

func test_peer_lookup_is_stable_by_steam_identity() -> void:
	var roster := {
		41: {"steam_id": 5001},
		77: {"steam_id": 5002},
	}
	assert_int(BackupAuthorityRules.peer_id_for_steam_id(roster, 5002)).is_equal(77)
	assert_int(BackupAuthorityRules.peer_id_for_steam_id(roster, 9999)).is_equal(0)
