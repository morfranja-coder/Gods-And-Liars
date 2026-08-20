class_name NightActionsTest
extends GdUnitTestSuite

func test_heretic_cannot_target_another_heretic() -> void:
	var players := _players_for_night()
	assert_bool(NightActionRules.can_target(players, 1, 2, PlayerState.Role.HERETIC)).is_false()
	assert_bool(NightActionRules.can_target(players, 1, 4, PlayerState.Role.HERETIC)).is_true()

func test_healer_can_protect_self() -> void:
	var players := _players_for_night()
	assert_bool(NightActionRules.can_target(players, 3, 3, PlayerState.Role.HEALER)).is_true()

func test_inquisitor_cannot_investigate_self() -> void:
	var players := _players_for_night()
	assert_bool(NightActionRules.can_target(players, 4, 4, PlayerState.Role.INQUISITOR)).is_false()

func test_wrong_role_cannot_submit_action() -> void:
	var players := _players_for_night()
	assert_bool(NightActionRules.can_target(players, 5, 4, PlayerState.Role.HERETIC)).is_false()

func test_two_heretics_can_kill_two_distinct_unprotected_targets() -> void:
	var players := _players_for_night()
	var targets: Array[int] = [4, 5]
	var result := NightResolver.resolve_many(players, targets, 0, 0)
	assert_int(result.killed_peer_ids.size()).is_equal(2)
	assert_bool(result.killed_peer_ids.has(4)).is_true()
	assert_bool(result.killed_peer_ids.has(5)).is_true()

func test_healer_blocks_one_target_from_double_kill() -> void:
	var players := _players_for_night()
	var targets: Array[int] = [4, 5]
	var result := NightResolver.resolve_many(players, targets, 4, 0)
	assert_int(result.killed_peer_ids.size()).is_equal(1)
	assert_bool(result.killed_peer_ids.has(4)).is_false()
	assert_bool(result.killed_peer_ids.has(5)).is_true()

func test_duplicate_heretic_target_only_kills_once() -> void:
	var players := _players_for_night()
	var targets: Array[int] = [5, 5]
	var result := NightResolver.resolve_many(players, targets, 0, 0)
	assert_int(result.killed_peer_ids.size()).is_equal(1)
	assert_int(result.killed_peer_ids[0]).is_equal(5)

func _players_for_night() -> Array[PlayerState]:
	var players: Array[PlayerState] = []
	players.append(_player(1, PlayerState.Role.HERETIC))
	players.append(_player(2, PlayerState.Role.HERETIC))
	players.append(_player(3, PlayerState.Role.HEALER))
	players.append(_player(4, PlayerState.Role.INQUISITOR))
	players.append(_player(5, PlayerState.Role.FAITHFUL))
	players.append(_player(6, PlayerState.Role.FAITHFUL))
	players.append(_player(7, PlayerState.Role.FAITHFUL))
	return players

func _player(peer_id: int, role: PlayerState.Role) -> PlayerState:
	var player := PlayerState.new(peer_id, 1000 + peer_id, "P%d" % peer_id)
	player.role = role
	return player
