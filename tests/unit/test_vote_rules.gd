class_name VoteRulesTest
extends GdUnitTestSuite

func test_living_player_can_vote_living_other_player() -> void:
	var players := _players()
	assert_bool(VoteRules.can_vote(players, 1, 2)).is_true()

func test_player_cannot_vote_self() -> void:
	var players := _players()
	assert_bool(VoteRules.can_vote(players, 1, 1)).is_false()

func test_dead_player_cannot_vote() -> void:
	var players := _players()
	players[0].alive = false
	assert_bool(VoteRules.can_vote(players, 1, 2)).is_false()

func test_cannot_vote_dead_target() -> void:
	var players := _players()
	players[1].alive = false
	assert_bool(VoteRules.can_vote(players, 1, 2)).is_false()

func test_resolve_requires_all_living_votes() -> void:
	var players := _players()
	var votes := {1: 2, 2: 1, 3: 2}
	assert_int(VoteRules.resolve(players, votes)).is_equal(0)

func test_resolve_returns_unique_winner() -> void:
	var players := _players()
	var votes := {1: 2, 2: 1, 3: 2, 4: 2}
	assert_int(VoteRules.resolve(players, votes)).is_equal(2)

func test_resolve_returns_zero_on_tie() -> void:
	var players := _players()
	var votes := {1: 2, 2: 1, 3: 4, 4: 3}
	assert_int(VoteRules.resolve(players, votes)).is_equal(0)

func _players() -> Array[PlayerState]:
	var result: Array[PlayerState] = []
	for peer_id in range(1, 5):
		result.append(PlayerState.new(peer_id, 1000 + peer_id, "P%d" % peer_id))
	return result
