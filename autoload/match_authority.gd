extends Node

signal private_role_received(role: int)
signal role_reveal_failed(reason: String)
signal phase_synced(phase: int)
signal night_action_accepted(actor_peer_id: int, target_peer_id: int)
signal night_resolution_received(killed_peer_ids: Array[int])
signal private_investigation_received(target_peer_id: int, is_heretic: bool)
signal vote_accepted(voter_peer_id: int, target_peer_id: int)
signal vote_resolution_received(sacrificed_peer_id: int, tied: bool)
signal match_end_received(winner: StringName)
signal rematch_received

var local_role: PlayerState.Role = PlayerState.Role.UNASSIGNED
var public_alive_by_peer: Dictionary = {}
var public_winner: StringName = &""
var _session: MatchSession = null
var _roles_dispatched: bool = false
var _role_acknowledged: Dictionary = {}
var _heretic_targets: Dictionary = {}
var _healer_target_peer_id: int = 0
var _inquisitor_target_peer_id: int = 0
var _votes: Dictionary = {}

func _ready() -> void:
	NetworkManager.lobby_state_changed.connect(_on_lobby_state_changed)

func reset() -> void:
	local_role = PlayerState.Role.UNASSIGNED
	public_alive_by_peer.clear()
	public_winner = &""
	_session = null
	_roles_dispatched = false
	_role_acknowledged.clear()
	_votes.clear()
	_reset_night_actions()

func begin_role_reveal() -> bool:
	if not multiplayer.is_server() or not NetworkManager.is_host or _roles_dispatched:
		return false
	var session := _build_session(NetworkManager.peers)
	if session == null or not session.prepare_match():
		role_reveal_failed.emit("Se necesitan al menos %d jugadores para repartir roles." % MatchSession.MIN_PLAYERS)
		return false
	_session = session
	_roles_dispatched = true
	public_winner = &""
	_initialize_public_alive()
	GameManager.start_match()
	_dispatch_private_roles()
	return true

func acknowledge_local_role() -> void:
	if local_role == PlayerState.Role.UNASSIGNED:
		return
	if multiplayer.is_server():
		_server_acknowledge_role(multiplayer.get_unique_id())
	else:
		_acknowledge_role.rpc_id(1)

func submit_local_night_target(target_peer_id: int) -> void:
	if not NightPhaseRules.is_action_phase(GameManager.phase):
		return
	if NightPhaseRules.role_for_phase(GameManager.phase) != local_role:
		return
	if multiplayer.is_server():
		_server_submit_night_action(multiplayer.get_unique_id(), target_peer_id)
	else:
		_request_night_action.rpc_id(1, target_peer_id)

func request_begin_voting() -> void:
	if not multiplayer.is_server() or not NetworkManager.is_host:
		return
	if GameManager.phase != GameManager.MatchPhase.DAY_DISCUSSION or _session == null:
		return
	_votes.clear()
	_sync_phase.rpc(int(GameManager.MatchPhase.VOTING))

func submit_local_vote(target_peer_id: int) -> void:
	if GameManager.phase != GameManager.MatchPhase.VOTING:
		return
	if multiplayer.multiplayer_peer == null:
		return
	var local_peer_id := multiplayer.get_unique_id()
	if not is_peer_publicly_alive(local_peer_id):
		return
	if multiplayer.is_server():
		_server_submit_vote(local_peer_id, target_peer_id)
	else:
		_request_vote.rpc_id(1, target_peer_id)

func request_rematch() -> void:
	if not multiplayer.is_server() or not NetworkManager.is_host:
		return
	if GameManager.phase != GameManager.MatchPhase.MATCH_END:
		return
	_sync_rematch.rpc()
	call_deferred("begin_role_reveal")

func server_role_for_peer(peer_id: int) -> PlayerState.Role:
	if not multiplayer.is_server() or _session == null:
		return PlayerState.Role.UNASSIGNED
	var player := _session.get_player(peer_id)
	return PlayerState.Role.UNASSIGNED if player == null else player.role

func is_peer_publicly_alive(peer_id: int) -> bool:
	return bool(public_alive_by_peer.get(peer_id, true))

func is_local_ghost() -> bool:
	if multiplayer.multiplayer_peer == null:
		return false
	var local_peer_id := multiplayer.get_unique_id()
	return public_alive_by_peer.has(local_peer_id) and not is_peer_publicly_alive(local_peer_id)

func role_title(role: PlayerState.Role = local_role) -> String:
	match role:
		PlayerState.Role.FAITHFUL:
			return "Fiel"
		PlayerState.Role.HERETIC:
			return "Hereje"
		PlayerState.Role.HEALER:
			return "Sanador"
		PlayerState.Role.INQUISITOR:
			return "Inquisidor"
		_:
			return "Sin revelar"

func role_description(role: PlayerState.Role = local_role) -> String:
	match role:
		PlayerState.Role.FAITHFUL:
			return "Descubrí a los herejes y sobreviví al ritual."
		PlayerState.Role.HERETIC:
			return "Eliminá a los fieles sin revelar tu identidad."
		PlayerState.Role.HEALER:
			return "Protegé a una persona durante la noche."
		PlayerState.Role.INQUISITOR:
			return "Investigá a una persona durante la noche."
		_:
			return "Esperando la voluntad de los dioses."

func _build_session(roster: Dictionary) -> MatchSession:
	if roster.size() < MatchSession.MIN_PLAYERS:
		return null
	var session := MatchSession.new()
	var peer_ids := roster.keys()
	peer_ids.sort()
	for raw_peer_id in peer_ids:
		var peer_id := int(raw_peer_id)
		var data: Dictionary = roster[raw_peer_id]
		if not session.add_player(peer_id, int(data.get("steam_id", 0)), str(data.get("display_name", ""))):
			return null
		var player := session.get_player(peer_id)
		player.seat_id = int(data.get("seat_id", -1))
	return session

func _initialize_public_alive() -> void:
	public_alive_by_peer.clear()
	for raw_peer_id in NetworkManager.peers.keys():
		public_alive_by_peer[int(raw_peer_id)] = true

func _dispatch_private_roles() -> void:
	for player in _session.players:
		if player.peer_id == multiplayer.get_unique_id():
			_receive_private_role(int(player.role))
		else:
			_receive_private_role.rpc_id(player.peer_id, int(player.role))

func _server_acknowledge_role(peer_id: int) -> void:
	if not multiplayer.is_server() or _session == null or _session.get_player(peer_id) == null:
		return
	_role_acknowledged[peer_id] = true
	if _role_acknowledged.size() == _session.players.size():
		_start_night()

func _start_night() -> void:
	_reset_night_actions()
	_sync_phase.rpc(int(GameManager.MatchPhase.NIGHT_START))
	_advance_night_phase()

func _advance_night_phase() -> void:
	if not multiplayer.is_server() or _session == null:
		return
	var next_phase := NightPhaseRules.next_action_phase(GameManager.phase)
	while NightPhaseRules.is_action_phase(next_phase):
		var role := NightPhaseRules.role_for_phase(next_phase)
		if NightActionRules.expected_actor_count(_session.players, role) > 0:
			_sync_phase.rpc(int(next_phase))
			return
		next_phase = NightPhaseRules.next_action_phase(next_phase)
	_sync_phase.rpc(int(GameManager.MatchPhase.NIGHT_RESOLUTION))
	_resolve_night()

func _server_submit_night_action(actor_peer_id: int, target_peer_id: int) -> void:
	if not multiplayer.is_server() or _session == null:
		return
	var required_role := NightPhaseRules.role_for_phase(GameManager.phase)
	if required_role == PlayerState.Role.UNASSIGNED:
		return
	if not NightActionRules.can_target(_session.players, actor_peer_id, target_peer_id, required_role):
		return
	match required_role:
		PlayerState.Role.HERETIC:
			_heretic_targets[actor_peer_id] = target_peer_id
		PlayerState.Role.HEALER:
			_healer_target_peer_id = target_peer_id
		PlayerState.Role.INQUISITOR:
			_inquisitor_target_peer_id = target_peer_id
	night_action_accepted.emit(actor_peer_id, target_peer_id)
	if _current_phase_has_all_actions(required_role):
		_advance_night_phase()

func _current_phase_has_all_actions(role: PlayerState.Role) -> bool:
	var expected := NightActionRules.expected_actor_count(_session.players, role)
	match role:
		PlayerState.Role.HERETIC:
			return _heretic_targets.size() >= expected
		PlayerState.Role.HEALER:
			return expected == 0 or _healer_target_peer_id != 0
		PlayerState.Role.INQUISITOR:
			return expected == 0 or _inquisitor_target_peer_id != 0
		_:
			return false

func _resolve_night() -> void:
	var targets: Array[int] = []
	for raw_target in _heretic_targets.values():
		targets.append(int(raw_target))
	var result := NightResolver.resolve_many(
		_session.players,
		targets,
		_healer_target_peer_id,
		_inquisitor_target_peer_id,
	)
	_sync_night_resolution.rpc(result.killed_peer_ids)
	_dispatch_investigation_result(result)
	_sync_phase.rpc(int(GameManager.MatchPhase.WIN_CHECK))
	_finish_or_continue_after_night()

func _dispatch_investigation_result(result: NightResolver.NightResult) -> void:
	if result.investigation_target_peer_id == 0:
		return
	for player in _session.players:
		if player.alive and player.role == PlayerState.Role.INQUISITOR:
			if player.peer_id == multiplayer.get_unique_id():
				_receive_private_investigation(result.investigation_target_peer_id, result.investigation_is_heretic)
			else:
				_receive_private_investigation.rpc_id(
					player.peer_id,
					result.investigation_target_peer_id,
					result.investigation_is_heretic,
				)
			return

func _server_submit_vote(voter_peer_id: int, target_peer_id: int) -> void:
	if not multiplayer.is_server() or _session == null or GameManager.phase != GameManager.MatchPhase.VOTING:
		return
	if not VoteRules.can_vote(_session.players, voter_peer_id, target_peer_id):
		return
	_votes[voter_peer_id] = target_peer_id
	vote_accepted.emit(voter_peer_id, target_peer_id)
	if _votes.size() >= VoteRules.living_count(_session.players):
		_resolve_vote()

func _resolve_vote() -> void:
	var sacrificed_peer_id := VoteRules.resolve(_session.players, _votes)
	var tied := sacrificed_peer_id == 0
	_sync_phase.rpc(int(GameManager.MatchPhase.SACRIFICE))
	if sacrificed_peer_id > 0:
		_session.sacrifice(sacrificed_peer_id)
		_sync_sacrifice.rpc(sacrificed_peer_id, false)
	else:
		_sync_sacrifice.rpc(0, true)
	_sync_phase.rpc(int(GameManager.MatchPhase.WIN_CHECK))
	_finish_or_continue_after_vote()

func _finish_or_continue_after_night() -> void:
	var winner := _session.winner()
	if not winner.is_empty():
		_end_match(winner)
		return
	_sync_phase.rpc(int(GameManager.MatchPhase.DAY_DISCUSSION))

func _finish_or_continue_after_vote() -> void:
	var winner := _session.winner()
	if not winner.is_empty():
		_end_match(winner)
		return
	GameManager.start_next_round()
	_start_night()

func _end_match(winner: StringName) -> void:
	_sync_match_end.rpc(str(winner))

func _reset_night_actions() -> void:
	_heretic_targets.clear()
	_healer_target_peer_id = 0
	_inquisitor_target_peer_id = 0

func _reset_for_rematch() -> void:
	local_role = PlayerState.Role.UNASSIGNED
	public_winner = &""
	_session = null
	_roles_dispatched = false
	_role_acknowledged.clear()
	_votes.clear()
	_reset_night_actions()
	_initialize_public_alive()
	GameManager.round_number = 0
	GameManager.set_phase(GameManager.MatchPhase.READY)

@rpc("authority", "call_remote", "reliable")
func _receive_private_role(role_value: int) -> void:
	if role_value <= PlayerState.Role.UNASSIGNED or role_value > PlayerState.Role.INQUISITOR:
		return
	local_role = role_value
	if public_alive_by_peer.is_empty():
		_initialize_public_alive()
	private_role_received.emit(int(local_role))

@rpc("any_peer", "reliable")
func _acknowledge_role() -> void:
	if not multiplayer.is_server():
		return
	_server_acknowledge_role(multiplayer.get_remote_sender_id())

@rpc("any_peer", "reliable")
func _request_night_action(target_peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	_server_submit_night_action(multiplayer.get_remote_sender_id(), target_peer_id)

@rpc("any_peer", "reliable")
func _request_vote(target_peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	_server_submit_vote(multiplayer.get_remote_sender_id(), target_peer_id)

@rpc("authority", "call_local", "reliable")
func _sync_phase(phase_value: int) -> void:
	if phase_value < GameManager.MatchPhase.BOOT or phase_value > GameManager.MatchPhase.MATCH_END:
		return
	GameManager.set_phase(phase_value)
	phase_synced.emit(phase_value)

@rpc("authority", "call_local", "reliable")
func _sync_night_resolution(killed_peer_ids: Array[int]) -> void:
	for peer_id in killed_peer_ids:
		public_alive_by_peer[int(peer_id)] = false
	night_resolution_received.emit(killed_peer_ids)

@rpc("authority", "call_local", "reliable")
func _sync_sacrifice(sacrificed_peer_id: int, tied: bool) -> void:
	if sacrificed_peer_id > 0:
		public_alive_by_peer[sacrificed_peer_id] = false
	vote_resolution_received.emit(sacrificed_peer_id, tied)

@rpc("authority", "call_local", "reliable")
func _sync_match_end(winner_value: String) -> void:
	var winner := StringName(winner_value)
	if winner not in [&"faithful", &"heretics"]:
		return
	public_winner = winner
	GameManager.end_match(winner)
	match_end_received.emit(winner)

@rpc("authority", "call_local", "reliable")
func _sync_rematch() -> void:
	_reset_for_rematch()
	rematch_received.emit()

@rpc("authority", "call_remote", "reliable")
func _receive_private_investigation(target_peer_id: int, is_heretic: bool) -> void:
	private_investigation_received.emit(target_peer_id, is_heretic)

func _on_lobby_state_changed(state: StringName) -> void:
	if state in [&"steam_ready", &"offline", &"host_disconnected", &"connection_failed"]:
		reset()
