extends "res://tests/acceptance/gate_d_full_night_actions.gd"

func _local_day_validation_error() -> String:
	var error := ""
	var local_peer_id := multiplayer.get_unique_id()
	var local_alive := MatchAuthority.is_peer_publicly_alive(local_peer_id)
	if GameManager.round_number != EXPECTED_ROUND:
		error = "day discussion round mismatch"
	elif NetworkManager.peers.size() != EXPECTED_PLAYERS:
		error = "roster changed during night"
	elif not _role_received:
		error = "day reached without private role"
	elif MatchAuthority.local_role != PlayerState.Role.FAITHFUL and not _action_accepted:
		error = "active role did not receive accepted night action"
	elif MatchAuthority.local_role == PlayerState.Role.HERETIC:
		if MatchAuthority.local_heretic_teammate_peer_id <= 0:
			error = "heretic teammate was not delivered"
	elif MatchAuthority.local_role == PlayerState.Role.INQUISITOR:
		if local_alive and not _investigation_received:
			error = "living inquisitor did not receive private result"
		elif not local_alive and _investigation_received:
			error = "dead inquisitor unexpectedly received private result"
	elif not _saw_full_night_sequence():
		error = "client missed part of the replicated night sequence"
	return error

func _client_day_ack_validation_error(
	sender_id: int,
	role_value: int,
	dead_peer_count: int,
	action_accepted: bool,
	heretic_teammate_peer_id: int,
	investigation_received: bool,
	investigation_target: int,
	investigation_is_heretic: bool,
	saw_full_night: bool,
) -> String:
	var expected_role := MatchAuthority.server_role_for_peer(sender_id)
	var error := ""
	if role_value != int(expected_role):
		error = "client role changed from authoritative role"
	elif dead_peer_count != _dead_peer_count():
		error = "client public death state diverged"
	elif expected_role != PlayerState.Role.FAITHFUL and not action_accepted:
		error = "active client role did not confirm accepted action"
	elif expected_role == PlayerState.Role.HERETIC:
		error = _validate_heretic_ack(sender_id, heretic_teammate_peer_id)
	elif expected_role == PlayerState.Role.INQUISITOR:
		var sender_alive := MatchAuthority.is_peer_publicly_alive(sender_id)
		if sender_alive:
			error = _validate_inquisitor_ack(
				investigation_received,
				investigation_target,
				investigation_is_heretic,
			)
		elif investigation_received:
			error = "dead inquisitor unexpectedly reported private investigation"
	elif not saw_full_night:
		error = "client did not observe full night phase sequence"
	return error
