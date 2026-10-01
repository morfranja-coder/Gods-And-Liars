class_name TextChatPolicyTest
extends GdUnitTestSuite

func test_general_chat_is_open_during_day_discussion() -> void:
	assert_bool(
		TextChatPolicy.can_general_chat(GameManager.MatchPhase.DAY_DISCUSSION, true)
	).is_true()

func test_general_chat_is_blocked_during_night_actions() -> void:
	for phase in [
		GameManager.MatchPhase.HERETIC_ACTION,
		GameManager.MatchPhase.HEALER_ACTION,
		GameManager.MatchPhase.INQUISITOR_ACTION,
	]:
		assert_bool(TextChatPolicy.can_general_chat(phase, true)).is_false()

func test_dead_player_cannot_use_general_chat() -> void:
	assert_bool(
		TextChatPolicy.can_general_chat(GameManager.MatchPhase.DAY_DISCUSSION, false)
	).is_false()

func test_private_chat_is_open_between_living_players_during_day() -> void:
	assert_bool(
		TextChatPolicy.can_private_chat(
			GameManager.MatchPhase.DAY_DISCUSSION,
			true,
			true,
			PlayerState.Role.FAITHFUL,
			PlayerState.Role.HEALER,
		)
	).is_true()

func test_heretic_night_private_chat_is_heretic_only() -> void:
	assert_bool(
		TextChatPolicy.can_private_chat(
			GameManager.MatchPhase.HERETIC_ACTION,
			true,
			true,
			PlayerState.Role.HERETIC,
			PlayerState.Role.HERETIC,
		)
	).is_true()
	assert_bool(
		TextChatPolicy.can_private_chat(
			GameManager.MatchPhase.HERETIC_ACTION,
			true,
			true,
			PlayerState.Role.HERETIC,
			PlayerState.Role.FAITHFUL,
		)
	).is_false()

func test_private_chat_is_blocked_during_other_night_roles() -> void:
	assert_bool(
		TextChatPolicy.can_private_chat(
			GameManager.MatchPhase.HEALER_ACTION,
			true,
			true,
			PlayerState.Role.HERETIC,
			PlayerState.Role.HERETIC,
		)
	).is_false()
