class_name MatchLeavePartyInvariantTest
extends GdUnitTestSuite

func test_identical_party_snapshot_is_preserved() -> void:
	var before := MatchLeavePartyInvariant.capture(
		8100,
		9100,
		7100,
		7001,
		{7001: "Leader", 7002: "Friend"},
	)
	var after := MatchLeavePartyInvariant.capture(
		8100,
		9100,
		7100,
		7001,
		{7001: "Leader", 7002: "Friend"},
	)
	assert_bool(MatchLeavePartyInvariant.is_preserved(before, after)).is_true()

func test_party_lobby_or_target_change_breaks_invariant() -> void:
	var before := _baseline()
	var changed_lobby := _baseline()
	changed_lobby["party_lobby_id"] = 0
	assert_bool(MatchLeavePartyInvariant.is_preserved(before, changed_lobby)).is_false()
	var changed_target := _baseline()
	changed_target["match_target_lobby_id"] = 0
	assert_bool(MatchLeavePartyInvariant.is_preserved(before, changed_target)).is_false()

func test_leader_or_members_change_breaks_invariant() -> void:
	var before := _baseline()
	var changed_leader := _baseline()
	changed_leader["leader_steam_id"] = 7002
	assert_bool(MatchLeavePartyInvariant.is_preserved(before, changed_leader)).is_false()
	var changed_members := _baseline()
	changed_members["members"] = {7001: "Leader"}
	assert_bool(MatchLeavePartyInvariant.is_preserved(before, changed_members)).is_false()

func test_capture_deep_copies_members() -> void:
	var members := {7001: "Leader", 7002: "Friend"}
	var snapshot := MatchLeavePartyInvariant.capture(8100, 9100, 7100, 7001, members)
	members.erase(7002)
	assert_int((snapshot["members"] as Dictionary).size()).is_equal(2)

func _baseline() -> Dictionary:
	return MatchLeavePartyInvariant.capture(
		8100,
		9100,
		7100,
		7001,
		{7001: "Leader", 7002: "Friend"},
	)
