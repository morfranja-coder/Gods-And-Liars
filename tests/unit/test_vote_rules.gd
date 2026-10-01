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

func test_resolution_uses_only_received_valid_votes() -> void:
	var players := _players()
	var votes := {1: 2, 2: 1, 3: 2}
	var result := VoteRules.resolve_sacrifice(players, votes, _rng(10))
	assert_int(int(result.get("peer_id", 0))).is_equal(2)
	assert_int(int(result.get("valid_vote_count", 0))).is_equal(3)
	assert_bool(bool(result.get("tied", true))).is_false()

func test_resolution_returns_unique_winner() -> void:
	var players := _players()
	var votes := {1: 2, 2: 1, 3: 2, 4: 2}
	assert_int(VoteRules.resolve(players, votes, _rng(11))).is_equal(2)

func test_tie_is_randomized_between_only_top_targets() -> void:
	var players := _players()
	var votes := {1: 2, 2: 1, 3: 4, 4: 3}
	var result := VoteRules.resolve_sacrifice(players, votes, _rng(12))
	var peer_id := int(result.get("peer_id", 0))
	assert_bool(bool(result.get("tied", false))).is_true()
	assert_bool(peer_id in [1, 2, 3, 4]).is_true()

func test_invalid_self_vote_is_excluded_from_resolution() -> void:
	var players := _players()
	var votes := {1: 1, 2: 3, 3: 2, 4: 2}
	var result := VoteRules.resolve_sacrifice(players, votes, _rng(13))
	assert_int(int(result.get("peer_id", 0))).is_equal(2)
	assert_int(int(result.get("valid_vote_count", 0))).is_equal(3)

func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func _players() -> Array[PlayerState]:
	var result: Array[PlayerState] = []
	for peer_id in range(1, 5):
		result.append(PlayerState.new(peer_id, 1000 + peer_id, "P%d" % peer_id))
	return result
