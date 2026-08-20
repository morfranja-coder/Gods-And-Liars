class_name NightActionRules
extends RefCounted

static func can_target(
	players: Array[PlayerState],
	actor_peer_id: int,
	target_peer_id: int,
	required_role: PlayerState.Role
) -> bool:
	var actor := _find_player(players, actor_peer_id)
	var target := _find_player(players, target_peer_id)
	if actor == null or target == null or not actor.alive or not target.alive:
		return false
	if actor.role != required_role:
		return false
	match required_role:
		PlayerState.Role.HERETIC:
			return actor.peer_id != target.peer_id and target.role != PlayerState.Role.HERETIC
		PlayerState.Role.HEALER:
			return true
		PlayerState.Role.INQUISITOR:
			return actor.peer_id != target.peer_id
		_:
			return false

static func expected_actor_count(players: Array[PlayerState], role: PlayerState.Role) -> int:
	var count := 0
	for player in players:
		if player.alive and player.role == role:
			count += 1
	return count

static func _find_player(players: Array[PlayerState], peer_id: int) -> PlayerState:
	for player in players:
		if player.peer_id == peer_id:
			return player
	return null
