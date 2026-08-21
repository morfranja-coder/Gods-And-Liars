class_name MatchSession
extends RefCounted

const MAX_PLAYERS := QuickMatchRules.TARGET_PLAYERS
const MIN_PLAYERS := QuickMatchRules.TARGET_PLAYERS

var players: Array[PlayerState] = []
var rng := RandomNumberGenerator.new()

func _init(seed_value: int = 0) -> void:
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value

func add_player(peer_id: int, steam_id: int, display_name: String) -> bool:
	if players.size() >= MAX_PLAYERS or get_player(peer_id) != null:
		return false
	var player := PlayerState.new(peer_id, steam_id, display_name)
	player.seat_id = _next_free_seat()
	players.append(player)
	return true

func remove_player(peer_id: int) -> void:
	var player := get_player(peer_id)
	if player != null:
		players.erase(player)

func get_player(peer_id: int) -> PlayerState:
	for player in players:
		if player.peer_id == peer_id:
			return player
	return null

func can_start() -> bool:
	if players.size() != MIN_PLAYERS:
		return false
	for player in players:
		if not player.ready:
			return false
	return true

func prepare_match() -> bool:
	if players.size() != MIN_PLAYERS:
		return false
	for player in players:
		player.reset_for_match()
	RoleRules.assign_roles(players, rng)
	return true

func living_players() -> Array[PlayerState]:
	var result: Array[PlayerState] = []
	for player in players:
		if player.alive:
			result.append(player)
	return result

func resolve_vote(votes: Dictionary) -> int:
	var counts: Dictionary = {}
	for voter_peer_id in votes:
		var voter := get_player(int(voter_peer_id))
		var target_peer_id := int(votes[voter_peer_id])
		var target := get_player(target_peer_id)
		if voter == null or target == null or not voter.alive or not target.alive:
			continue
		counts[target_peer_id] = int(counts.get(target_peer_id, 0)) + 1
	if counts.is_empty():
		return 0
	var highest := 0
	var winner_peer_id := 0
	var tied := false
	for target_peer_id in counts:
		var count := int(counts[target_peer_id])
		if count > highest:
			highest = count
			winner_peer_id = int(target_peer_id)
			tied = false
		elif count == highest:
			tied = true
	return 0 if tied else winner_peer_id

func sacrifice(peer_id: int) -> bool:
	var player := get_player(peer_id)
	if player == null or not player.alive:
		return false
	player.alive = false
	return true

func winner() -> StringName:
	return RoleRules.winner(players)

func _next_free_seat() -> int:
	for seat in range(MAX_PLAYERS):
		var occupied := false
		for player in players:
			if player.seat_id == seat:
				occupied = true
				break
		if not occupied:
			return seat
	return -1
