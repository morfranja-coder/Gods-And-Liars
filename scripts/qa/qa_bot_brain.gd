class_name QABotBrain
extends RefCounted

enum Profile {
	BALANCED,
	TIMEOUT,
}

var profile: Profile = Profile.BALANCED

func _init(profile_value: Profile = Profile.BALANCED) -> void:
	profile = profile_value

func choose_night_target(players: Array[PlayerState], actor_peer_id: int) -> int:
	if profile == Profile.TIMEOUT:
		return 0
	var actor := _find_player(players, actor_peer_id)
	if actor == null or not actor.alive:
		return 0
	var candidate_ids: Array[int] = []
	for target in players:
		if NightActionRules.can_target(players, actor_peer_id, target.peer_id, actor.role):
			candidate_ids.append(target.peer_id)
	candidate_ids.sort()
	if candidate_ids.is_empty():
		return 0
	if actor.role == PlayerState.Role.HEALER and actor_peer_id in candidate_ids:
		return actor_peer_id
	return candidate_ids[0]

func choose_vote_target(players: Array[PlayerState], voter_peer_id: int) -> int:
	if profile == Profile.TIMEOUT:
		return 0
	var candidate_ids: Array[int] = []
	for target in players:
		if VoteRules.can_vote(players, voter_peer_id, target.peer_id):
			candidate_ids.append(target.peer_id)
	candidate_ids.sort()
	return 0 if candidate_ids.is_empty() else candidate_ids[0]

func _find_player(players: Array[PlayerState], peer_id: int) -> PlayerState:
	for player in players:
		if player.peer_id == peer_id:
			return player
	return null
