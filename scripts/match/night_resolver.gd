class_name NightResolver
extends RefCounted

class NightResult:
	var victim_peer_ids: Array[int] = []
	var protected_peer_id: int = 0
	var killed_peer_ids: Array[int] = []
	var investigation_target_peer_id: int = 0
	var investigation_is_heretic: bool = false
	var kill_suppressed: bool = false

	var victim_peer_id: int:
		get:
			return victim_peer_ids[0] if not victim_peer_ids.is_empty() else 0

	var killed_peer_id: int:
		get:
			return killed_peer_ids[0] if not killed_peer_ids.is_empty() else 0

static func resolve(
	players: Array[PlayerState],
	heretic_target_peer_id: int,
	healer_target_peer_id: int,
	inquisitor_target_peer_id: int,
	suppress_kills: bool = false
) -> NightResult:
	var targets: Array[int] = []
	if heretic_target_peer_id != 0:
		targets.append(heretic_target_peer_id)
	return resolve_many(
		players,
		targets,
		healer_target_peer_id,
		inquisitor_target_peer_id,
		suppress_kills,
	)

static func resolve_many(
	players: Array[PlayerState],
	heretic_target_peer_ids: Array[int],
	healer_target_peer_id: int,
	inquisitor_target_peer_id: int,
	suppress_kills: bool = false
) -> NightResult:
	var result := NightResult.new()
	result.protected_peer_id = healer_target_peer_id
	result.investigation_target_peer_id = inquisitor_target_peer_id
	result.kill_suppressed = suppress_kills

	var seen_targets: Dictionary = {}
	for target_peer_id in heretic_target_peer_ids:
		if target_peer_id == 0 or seen_targets.has(target_peer_id):
			continue
		seen_targets[target_peer_id] = true
		result.victim_peer_ids.append(target_peer_id)
		if suppress_kills or target_peer_id == healer_target_peer_id:
			continue
		var victim := _find_alive_player(players, target_peer_id)
		if victim != null:
			victim.alive = false
			result.killed_peer_ids.append(victim.peer_id)

	if inquisitor_target_peer_id != 0:
		var target := _find_player(players, inquisitor_target_peer_id)
		if target != null:
			result.investigation_is_heretic = target.role == PlayerState.Role.HERETIC

	return result

static func _find_alive_player(players: Array[PlayerState], peer_id: int) -> PlayerState:
	var player := _find_player(players, peer_id)
	return player if player != null and player.alive else null

static func _find_player(players: Array[PlayerState], peer_id: int) -> PlayerState:
	for player in players:
		if player.peer_id == peer_id:
			return player
	return null
