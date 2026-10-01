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
	return VoteRules.resolve(players, votes, rng)

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
