class_name QABotSimulatorTest
extends GdUnitTestSuite

func test_balanced_bot_chooses_only_valid_targets() -> void:
	var session := MatchSession.new(1234)
	for peer_id in range(1, QuickMatchRules.TARGET_PLAYERS + 1):
		assert_bool(session.add_player(peer_id, 800000 + peer_id, "Bot %d" % peer_id)).is_true()
	assert_bool(session.prepare_match()).is_true()
	var brain := QABotBrain.new(QABotBrain.Profile.BALANCED)
	for player in session.players:
		if player.role in [
			PlayerState.Role.HERETIC,
			PlayerState.Role.HEALER,
			PlayerState.Role.INQUISITOR,
		]:
			var target := brain.choose_night_target(session.players, player.peer_id)
			assert_bool(
				NightActionRules.can_target(session.players, player.peer_id, target, player.role)
			).is_true()

func test_timeout_bot_submits_no_actions() -> void:
	var session := MatchSession.new(77)
	for peer_id in range(1, QuickMatchRules.TARGET_PLAYERS + 1):
		session.add_player(peer_id, 810000 + peer_id, "Bot %d" % peer_id)
	session.prepare_match()
	var brain := QABotBrain.new(QABotBrain.Profile.TIMEOUT)
	assert_int(brain.choose_night_target(session.players, 1)).is_equal(0)
	assert_int(brain.choose_vote_target(session.players, 1)).is_equal(0)

func test_synthetic_match_completes_with_exactly_eight_players() -> void:
	var result := QAMatchSimulator.run(42)
	assert_bool(bool(result.get("completed", false))).is_true()
	assert_int(int(result.get("players", 0))).is_equal(QuickMatchRules.TARGET_PLAYERS)
	assert_str(str(result.get("winner", ""))).is_not_empty()

func test_one_hundred_synthetic_matches_complete_without_deadlock() -> void:
	for seed_value in range(1, 101):
		var result := QAMatchSimulator.run(seed_value)
		assert_bool(bool(result.get("completed", false))).override_failure_message(
			"Synthetic match deadlocked for seed %d: %s" % [seed_value, result]
		).is_true()
		assert_int(int(result.get("rounds", 999))).is_less_equal(QAMatchSimulator.DEFAULT_MAX_ROUNDS)
