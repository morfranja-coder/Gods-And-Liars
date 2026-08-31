extends "res://autoload/match_authority.gd"

func _dispatch_private_roles() -> void:
	if not PracticeManager.active:
		super._dispatch_private_roles()
		return
	for player in _session.players:
		if not player.alive:
			continue
		if PracticeManager.is_bot(player.peer_id):
			continue
		_receive_private_role(int(player.role))
		if player.role != PlayerState.Role.HERETIC:
			continue
		var teammate := _heretic_teammate_for(player.peer_id)
		if teammate != null:
			_receive_private_heretic_teammate(teammate.peer_id, teammate.display_name)

func _send_night_action_result(actor_peer_id: int, accepted: bool, target_peer_id: int) -> void:
	if PracticeManager.active and PracticeManager.is_bot(actor_peer_id):
		return
	super._send_night_action_result(actor_peer_id, accepted, target_peer_id)

func _dispatch_investigation_result(result: NightResolver.NightResult) -> void:
	if not PracticeManager.active:
		super._dispatch_investigation_result(result)
		return
	if result.investigation_target_peer_id == 0:
		return
	for player in _session.players:
		if not player.alive or player.role != PlayerState.Role.INQUISITOR:
			continue
		if PracticeManager.is_bot(player.peer_id):
			return
		_receive_private_investigation(
			result.investigation_target_peer_id,
			result.investigation_is_heretic,
		)
		return
