class_name NightRoundRulesTest
extends GdUnitTestSuite

func test_decider_alternates_between_living_heretics() -> void:
	var players := _players()
	assert_int(NightRoundRules.choose_heretic_decider(players, 1)).is_equal(1)
	assert_int(NightRoundRules.choose_heretic_decider(players, 2)).is_equal(2)
	assert_int(NightRoundRules.choose_heretic_decider(players, 3)).is_equal(1)

func test_dead_heretic_is_removed_from_decider_rotation() -> void:
	var players := _players()
	players[0].alive = false
	assert_int(NightRoundRules.choose_heretic_decider(players, 1)).is_equal(2)
	assert_int(NightRoundRules.choose_heretic_decider(players, 2)).is_equal(2)

func test_first_night_only_heretic_can_submit_action() -> void:
	var players := _players()
	assert_bool(
		NightRoundRules.can_submit_action(
			players, 1, 5, PlayerState.Role.HERETIC, 1, 1, false
		)
	).is_true()
	assert_bool(
		NightRoundRules.can_submit_action(
			players, 2, 5, PlayerState.Role.HERETIC, 1, 1, false
		)
	).is_false()
	assert_bool(
		NightRoundRules.can_submit_action(
			players, 3, 3, PlayerState.Role.HEALER, 1, 1, false
		)
	).is_false()
	assert_bool(
		NightRoundRules.can_submit_action(
			players, 4, 5, PlayerState.Role.INQUISITOR, 1, 1, false
		)
	).is_false()

func test_healer_self_save_is_rejected_after_it_was_used() -> void:
	var players := _players()
	assert_bool(
		NightRoundRules.can_submit_action(
			players, 3, 3, PlayerState.Role.HEALER, 2, 1, false
		)
	).is_true()
	assert_bool(
		NightRoundRules.can_submit_action(
			players, 3, 3, PlayerState.Role.HEALER, 3, 2, true
		)
	).is_false()
	assert_bool(
		NightRoundRules.can_submit_action(
			players, 3, 5, PlayerState.Role.HEALER, 3, 2, true
		)
	).is_true()

func _players() -> Array[PlayerState]:
	return [
		_player(1, PlayerState.Role.HERETIC),
		_player(2, PlayerState.Role.HERETIC),
		_player(3, PlayerState.Role.HEALER),
		_player(4, PlayerState.Role.INQUISITOR),
		_player(5, PlayerState.Role.FAITHFUL),
		_player(6, PlayerState.Role.FAITHFUL),
	]

func _player(peer_id: int, role: PlayerState.Role) -> PlayerState:
	var player := PlayerState.new(peer_id, 1000 + peer_id, "P%d" % peer_id)
	player.role = role
	return player
