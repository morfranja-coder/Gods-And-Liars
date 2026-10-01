class_name NightRoundRules
extends RefCounted

static func is_first_night(round_number: int) -> bool:
	return round_number == 1

static func choose_heretic_decider(
	players: Array[PlayerState],
	round_number: int,
) -> int:
	var living_heretics: Array[int] = []
	for player in players:
		if player.alive and player.role == PlayerState.Role.HERETIC:
			living_heretics.append(player.peer_id)
	living_heretics.sort()
	if living_heretics.is_empty():
		return 0
	var index := (maxi(1, round_number) - 1) % living_heretics.size()
	return living_heretics[index]

static func role_can_act(
	round_number: int,
	role: PlayerState.Role,
) -> bool:
	if is_first_night(round_number):
		return role == PlayerState.Role.HERETIC
	return role in [
		PlayerState.Role.HERETIC,
		PlayerState.Role.HEALER,
		PlayerState.Role.INQUISITOR,
	]

static func can_submit_action(
	players: Array[PlayerState],
	actor_peer_id: int,
	target_peer_id: int,
	required_role: PlayerState.Role,
	round_number: int,
	heretic_decider_peer_id: int,
	healer_self_save_used: bool,
) -> bool:
	if not role_can_act(round_number, required_role):
		return false
	if (
		required_role == PlayerState.Role.HERETIC
		and actor_peer_id != heretic_decider_peer_id
	):
		return false
	if (
		required_role == PlayerState.Role.HEALER
		and actor_peer_id == target_peer_id
		and healer_self_save_used
	):
		return false
	return NightActionRules.can_target(
		players,
		actor_peer_id,
		target_peer_id,
		required_role,
	)
