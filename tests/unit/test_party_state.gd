class_name PartyStateTest
extends GdUnitTestSuite

func test_solo_party_is_queueable() -> void:
	var party := PartyState.new()
	party.reset_to_solo(1001, "Leader")
	assert_int(party.size()).is_equal(1)
	assert_bool(party.is_leader(1001)).is_true()
	assert_bool(party.can_queue()).is_true()

func test_party_preserves_members_and_never_exceeds_eight() -> void:
	var party := PartyState.new()
	party.reset_to_solo(1001, "P1")
	for steam_id in range(1002, 1009):
		assert_bool(party.add_member(steam_id, "P%d" % steam_id)).is_true()
	assert_int(party.size()).is_equal(QuickMatchRules.TARGET_PLAYERS)
	assert_bool(party.add_member(1009, "TooMany")).is_false()

func test_leader_migrates_deterministically_inside_party_state() -> void:
	var party := PartyState.new()
	party.reset_to_solo(1002, "Leader")
	party.add_member(1001, "Friend")
	assert_bool(party.remove_member(1002)).is_true()
	assert_int(party.leader_steam_id).is_equal(1001)
