class_name VoteRules
extends RefCounted

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

static func resolve(players: Array[PlayerState], votes: Dictionary) -> int:
	var valid_votes: Dictionary = {}
	for raw_voter_id in votes.keys():
		var voter_id := int(raw_voter_id)
		var target_id := int(votes[raw_voter_id])
		if can_vote(players, voter_id, target_id):
			valid_votes[voter_id] = target_id
	if valid_votes.size() < living_count(players):
		return 0
	var counts: Dictionary = {}
	for target_id in valid_votes.values():
		counts[int(target_id)] = int(counts.get(int(target_id), 0)) + 1
	var highest := 0
	var winner_peer_id := 0
	var tied := false
	for raw_target_id in counts.keys():
		var target_id := int(raw_target_id)
		var count := int(counts[raw_target_id])
		if count > highest:
			highest = count
			winner_peer_id = target_id
			tied = false
		elif count == highest:
			tied = true
	return 0 if tied else winner_peer_id

static func _find_player(players: Array[PlayerState], peer_id: int) -> PlayerState:
	for player in players:
		if player.peer_id == peer_id:
			return player
	return null
