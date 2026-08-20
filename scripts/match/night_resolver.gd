class_name NightResolver
extends RefCounted

class NightResult:
	var victim_peer_id: int = 0
	var protected_peer_id: int = 0
	var killed_peer_id: int = 0
	var investigation_target_peer_id: int = 0
	var investigation_is_heretic: bool = false

static func resolve(
	players: Array[PlayerState],
	heretic_target_peer_id: int,
	healer_target_peer_id: int,
	inquisitor_target_peer_id: int
) -> NightResult:
	var result := NightResult.new()
	result.victim_peer_id = heretic_target_peer_id
	result.protected_peer_id = healer_target_peer_id
	result.investigation_target_peer_id = inquisitor_target_peer_id

	if heretic_target_peer_id != 0 and heretic_target_peer_id != healer_target_peer_id:
		var victim := _find_alive_player(players, heretic_target_peer_id)
		if victim != null:
			victim.alive = false
			result.killed_peer_id = victim.peer_id

	if inquisitor_target_peer_id != 0:
		var target := _find_alive_or_dead_player(players, inquisitor_target_peer_id)
		if target != null:
			result.investigation_is_heretic = target.role == PlayerState.Role.HERETIC

	return result

static func _find_alive_player(players: Array[PlayerState], peer_id: int) -> PlayerState:
	for player in players:
		if player.peer_id == peer_id and player.alive:
			return player
	return null

static func _find_alive_or_dead_player(players: Array[PlayerState], peer_id: int) -> PlayerState:
	for player in players:
		if player.peer_id == peer_id:
			return player
	return null
