extends GdUnitTestSuite

func before_test() -> void:
	PracticeManager.stop_practice()
	PracticeManager.start_seven_bot_match()

func after_test() -> void:
	PracticeManager.stop_practice()

func test_private_discoveries_do_not_leak_between_bots() -> void:
	BotDirector.record_investigation(2, 3, true)
	var own := BotDirector.build_prompt(2)
	var other := BotDirector.build_prompt(4)
	assert_str(own).contains('"3":true')
	assert_str(other).not_contains('"3":true')

func test_investigation_changes_vote_without_reading_other_roles() -> void:
	BotDirector.record_investigation(2, 3, true)
	BotDirector.record_investigation(2, 4, false)
	var candidates: Array[int] = [3, 4, 5]
	assert_int(BotDirector.preferred_vote(2, candidates)).is_equal(3)
	assert_int(BotDirector.preferred_vote(2, [4, 5])).is_equal(5)

func test_memory_is_bounded_and_names_unique() -> void:
	for index in range(40):
		BotDirector.remember(2, "message %d" % index)
	assert_int(BotDirector.history.size()).is_equal(18)
	var unique := {}
	for name_text in BotDirector.NAMES:
		unique[name_text] = true
	assert_int(unique.size()).is_equal(7)

func test_fallback_uses_server_language() -> void:
	var original: String = BotDirector.server_language
	BotDirector.server_language = "en"
	assert_str(BotDirector.build_prompt(2)).contains("Speak only English")
	BotDirector.server_language = "es"
	assert_str(BotDirector.build_prompt(2)).contains("Speak only Spanish")
	BotDirector.server_language = original
