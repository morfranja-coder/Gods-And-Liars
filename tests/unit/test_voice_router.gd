class_name VoiceRouterTest
extends GdUnitTestSuite

func test_lobby_voice_is_open() -> void:
	assert_bool(VoiceRouter.can_receive(GameManager.MatchPhase.LOBBY, true, true)).is_true()
	assert_bool(VoiceRouter.can_receive(GameManager.MatchPhase.LOBBY, false, true)).is_true()

func test_night_voice_is_muted() -> void:
	assert_bool(VoiceRouter.can_transmit(GameManager.MatchPhase.HERETIC_ACTION, true)).is_false()
	assert_bool(VoiceRouter.can_receive(GameManager.MatchPhase.HEALER_ACTION, true, true)).is_false()

func test_living_day_voice_reaches_everyone() -> void:
	assert_bool(VoiceRouter.can_receive(GameManager.MatchPhase.DAY_DISCUSSION, true, true)).is_true()
	assert_bool(VoiceRouter.can_receive(GameManager.MatchPhase.DAY_DISCUSSION, true, false)).is_true()

func test_dead_day_voice_only_reaches_dead() -> void:
	assert_bool(VoiceRouter.can_receive(GameManager.MatchPhase.DAY_DISCUSSION, false, true)).is_false()
	assert_bool(VoiceRouter.can_receive(GameManager.MatchPhase.DAY_DISCUSSION, false, false)).is_true()
