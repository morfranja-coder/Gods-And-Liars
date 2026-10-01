class_name VoteRules
extends RefCounted

const TURN_MS := 8000
const PHASE_SAFETY_MARGIN_MS := 5000

static func can_vote(players: Array[PlayerState], voter_peer_id: int, target_peer_id: int) -> bool:
	var voter := _find_player(players, voter_peer_id)
	var target := _find_player(players, target_peer_id)
	if voter == null or target == null:
		return false
	if not voter.alive or not target.alive:
		return false
	return voter_peer_id != target_peer_id

static func living_count(players: Array[PlayerState]) -> int:
	var count := 0
	for player in players:
		if player.alive:
			count += 1
	return count

static func valid_vote_count(players: Array[PlayerState], votes: Dictionary) -> int:
	return _valid_votes(players, votes).size()

static func resolve_sacrifice(
	players: Array[PlayerState],
	votes: Dictionary,
	rng: RandomNumberGenerator,
) -> Dictionary:
	var top := top_targets(players, votes)
	var tied := top.size() > 1
	var peer_id := 0
	if top.size() == 1:
		peer_id = top[0]
	elif tied and rng != null:
		peer_id = top[rng.randi_range(0, top.size() - 1)]
	return {
		"peer_id": peer_id,
		"tied": tied,
		"valid_vote_count": valid_vote_count(players, votes),
	}

static func resolve(
	players: Array[PlayerState],
	votes: Dictionary,
	rng: RandomNumberGenerator,
) -> int:
	return int(resolve_sacrifice(players, votes, rng).get("peer_id", 0))

static func top_targets(players: Array[PlayerState], votes: Dictionary) -> Array[int]:
	var valid_votes := _valid_votes(players, votes)
	var result: Array[int] = []
	if valid_votes.is_empty():
		return result
	var counts: Dictionary = {}
	var highest := 0
	for raw_target_id in valid_votes.values():
		var target_id := int(raw_target_id)
		var count := int(counts.get(target_id, 0)) + 1
		counts[target_id] = count
		highest = maxi(highest, count)
	for raw_target_id in counts.keys():
		if int(counts[raw_target_id]) == highest:
			result.append(int(raw_target_id))
	result.sort()
	return result

static func _valid_votes(players: Array[PlayerState], votes: Dictionary) -> Dictionary:
	var valid_votes: Dictionary = {}
	for raw_voter_id in votes.keys():
		var voter_id := int(raw_voter_id)
		var target_id := int(votes[raw_voter_id])
		if can_vote(players, voter_id, target_id):
			valid_votes[voter_id] = target_id
	return valid_votes

static func _find_player(players: Array[PlayerState], peer_id: int) -> PlayerState:
	for player in players:
		if player.peer_id == peer_id:
			return player
	return null
