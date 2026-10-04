class_name VoteRulesExactEightTieTest
extends GdUnitTestSuite

func test_four_way_two_two_two_two_tie_is_seed_reproducible() -> void:
	var players := _players()
	var votes := {
		1: 2,
		2: 1,
		3: 1,
		4: 2,
		5: 3,
		6: 3,
		7: 4,
		8: 4,
	}
	assert_array(VoteRules.top_targets(players, votes)).is_equal([1, 2, 3, 4])
	var first := _resolve_with_seed(players, votes, 991)
	var second := _resolve_with_seed(players, votes, 991)
	assert_int(first).is_equal(second)
	assert_bool(first in [1, 2, 3, 4]).is_true()

func test_three_three_one_one_tie_is_seed_reproducible() -> void:
	var players := _players()
	var votes := {
		1: 2,
		2: 1,
		3: 1,
		4: 1,
		5: 2,
		6: 2,
		7: 3,
		8: 4,
	}
	assert_array(VoteRules.top_targets(players, votes)).is_equal([1, 2])
	var first := _resolve_with_seed(players, votes, 2026)
	var second := _resolve_with_seed(players, votes, 2026)
	assert_int(first).is_equal(second)
	assert_bool(first in [1, 2]).is_true()

func _resolve_with_seed(
	players: Array[PlayerState],
	votes: Dictionary,
	seed_value: int,
) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return VoteRules.resolve(players, votes, rng)

func _players() -> Array[PlayerState]:
	var players: Array[PlayerState] = []
	for peer_id in range(1, 9):
		players.append(
			PlayerState.new(peer_id, 950000 + peer_id, "Tie P%d" % peer_id)
		)
	return players
