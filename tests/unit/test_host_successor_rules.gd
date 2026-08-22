class_name HostSuccessorRulesTest
extends GdUnitTestSuite

func test_lowest_alive_steam_id_wins_regardless_of_peer_id() -> void:
	var roster := {
		7: {"steam_id": 9007},
		2: {"steam_id": 9002},
		5: {"steam_id": 9005},
	}
	var alive := {7: true, 2: true, 5: true}
	assert_int(HostSuccessorRules.choose_successor_steam_id(roster, alive, 9007)).is_equal(9002)

func test_current_host_is_excluded() -> void:
	var roster := {
		1: {"steam_id": 1001},
		2: {"steam_id": 1002},
	}
	var alive := {1: true, 2: true}
	assert_int(HostSuccessorRules.choose_successor_steam_id(roster, alive, 1001)).is_equal(1002)

func test_alive_player_is_preferred_over_lower_dead_steam_id() -> void:
	var roster := {
		2: {"steam_id": 1002},
		3: {"steam_id": 1003},
		4: {"steam_id": 1004},
	}
	var alive := {2: false, 3: true, 4: true}
	assert_int(HostSuccessorRules.choose_successor_steam_id(roster, alive, 9999)).is_equal(1003)

func test_dead_player_is_used_as_fallback_when_no_alive_candidate_exists() -> void:
	var roster := {
		2: {"steam_id": 1002},
		3: {"steam_id": 1003},
	}
	var alive := {2: false, 3: false}
	assert_int(HostSuccessorRules.choose_successor_steam_id(roster, alive, 9999)).is_equal(1002)

func test_invalid_steam_ids_are_ignored() -> void:
	var roster := {
		2: {"steam_id": 0},
		3: {"steam_id": -5},
		4: {"steam_id": 1004},
	}
	var alive := {2: true, 3: true, 4: true}
	assert_int(HostSuccessorRules.choose_successor_steam_id(roster, alive, 9999)).is_equal(1004)

func test_no_candidate_returns_zero() -> void:
	var roster := {1: {"steam_id": 1001}}
	var alive := {1: true}
	assert_int(HostSuccessorRules.choose_successor_steam_id(roster, alive, 1001)).is_equal(0)
