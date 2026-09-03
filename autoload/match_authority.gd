extends Node

signal private_role_received(role: int)
signal private_heretic_teammate_received(peer_id: int, display_name: String)
signal private_priest_warning_received(target_peer_id: int)
signal role_reveal_failed(reason: String)
signal phase_synced(phase: int)
signal phase_timing_synced(phase: int, duration_ms: int)
signal phase_timeout_triggered(phase: int)
signal heretic_decider_changed(peer_id: int)
signal night_action_accepted(actor_peer_id: int, target_peer_id: int)
signal night_action_result_received(accepted: bool, target_peer_id: int)
signal night_resolution_received(killed_peer_ids: Array[int])
signal night_public_report_received(killed_peer_ids: Array[int], priest_saved: bool, first_night: bool)
signal private_investigation_received(target_peer_id: int, is_heretic: bool)
signal vote_accepted(voter_peer_id: int, target_peer_id: int)
signal vote_resolution_received(sacrificed_peer_id: int, tied: bool)
signal sacrifice_reveal_received(sacrificed_peer_id: int, tied: bool, was_heretic: bool)
signal match_end_received(winner: StringName)
signal rematch_received

var local_role: PlayerState.Role = PlayerState.Role.UNASSIGNED
var local_heretic_teammate_peer_id: int = 0
var local_heretic_teammate_name: String = ""
var current_heretic_decider_peer_id: int = 0
var public_alive_by_peer: Dictionary = {}
var public_winner: StringName = &""
var last_night_killed_peer_ids: Array[int] = []
var last_night_priest_saved: bool = false
var last_night_was_first: bool = false
var last_sacrificed_peer_id: int = 0
var last_sacrifice_was_tie: bool = false
var last_sacrifice_was_heretic: bool = false

var _session: MatchSession = null
var _roles_dispatched: bool = false
var _role_acknowledged: Dictionary = {}
var _heretic_targets: Dictionary = {}
var _healer_target_peer_id: int = 0
var _inquisitor_target_peer_id: int = 0
var _healer_self_save_used: bool = false
var _votes: Dictionary = {}
var _phase_deadline_ms: int = 0
var _phase_deadline_phase: int = -1
var _local_phase_started_ms: int = 0
var _local_phase_duration_ms: int = 0

func _ready() -> void:
	NetworkManager.lobby_state_changed.connect(_on_lobby_state_changed)
	NetworkManager.peer_left.connect(_on_peer_left)

func _process(_delta: float) -> void:
	if _phase_deadline_ms <= 0 or _session == null:
		return
	if not multiplayer.is_server() or not NetworkManager.is_host:
		return
	if int(GameManager.phase) != _phase_deadline_phase:
		_clear_phase_timeout()
		return
	if Time.get_ticks_msec() < _phase_deadline_ms:
		return
	var expired_phase := GameManager.phase
	_clear_phase_timeout()
	phase_timeout_triggered.emit(int(expired_phase))
	_handle_phase_timeout(expired_phase)

func reset() -> void:
	local_role = PlayerState.Role.UNASSIGNED
	local_heretic_teammate_peer_id = 0
	local_heretic_teammate_name = ""
	current_heretic_decider_peer_id = 0
	public_alive_by_peer.clear()
	public_winner = &""
	last_night_killed_peer_ids.clear()
	last_night_priest_saved = false
	last_night_was_first = false
	last_sacrificed_peer_id = 0
	last_sacrifice_was_tie = false
	last_sacrifice_was_heretic = false
	_session = null
	_roles_dispatched = false
	_role_acknowledged.clear()
	_votes.clear()
	_healer_self_save_used = false
	_reset_night_actions()
	_clear_phase_timeout()
	_local_phase_started_ms = 0
	_local_phase_duration_ms = 0

func begin_role_reveal() -> bool:
	if not multiplayer.is_server() or not NetworkManager.is_host or _roles_dispatched:
		return false
	var session := _build_session(NetworkManager.peers)
	if session == null or not session.prepare_match():
		role_reveal_failed.emit(
			"Se necesitan al menos %d jugadores para repartir roles." % MatchSession.MIN_PLAYERS
		)
		return false
	_session = session
	_roles_dispatched = true
	public_winner = &""
	_healer_self_save_used = false
	_initialize_public_alive()
	GameManager.start_match()
	_broadcast_phase(GameManager.MatchPhase.ROLE_REVEAL)
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
	if is_local_ghost() or not NightPhaseRules.is_action_phase(GameManager.phase):
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
	_broadcast_phase(GameManager.MatchPhase.VOTING)

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

func is_local_heretic_decider() -> bool:
	if multiplayer.multiplayer_peer == null or local_role != PlayerState.Role.HERETIC:
		return false
	return multiplayer.get_unique_id() == current_heretic_decider_peer_id

func phase_seconds_remaining() -> int:
	if _local_phase_duration_ms <= 0:
		return 0
	var elapsed := Time.get_ticks_msec() - _local_phase_started_ms
	var remaining := maxi(0, _local_phase_duration_ms - elapsed)
	return int(ceil(float(remaining) / 1000.0))

func role_title(role: PlayerState.Role = local_role) -> String:
	match role:
		PlayerState.Role.FAITHFUL:
			return "Fiel"
		PlayerState.Role.HERETIC:
			return "Hereje"
		PlayerState.Role.HEALER:
			return "Sacerdote"
		PlayerState.Role.INQUISITOR:
			return "Inquisidor"
		_:
			return "Sin revelar"

func role_description(role: PlayerState.Role = local_role) -> String:
	match role:
		PlayerState.Role.FAITHFUL:
			return "Descubrí a los herejes y sobreviví al ritual."
		PlayerState.Role.HERETIC:
			if not local_heretic_teammate_name.is_empty():
				return "Eliminá a los fieles sin revelar tu identidad. Tu compañero hereje es %s." % local_heretic_teammate_name
			return "Eliminá a los fieles sin revelar tu identidad."
		PlayerState.Role.HEALER:
			return "Protegé a los hijos del dios durante la noche."
		PlayerState.Role.INQUISITOR:
			return "Descubrí la verdad detrás de una máscara por noche."
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
		if not session.add_player(
			peer_id,
			int(data.get("steam_id", 0)),
			str(data.get("display_name", "")),
		):
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
		if not player.alive:
			continue
		_dispatch_role_to_player(player)
		if player.role == PlayerState.Role.HERETIC:
			_dispatch_heretic_teammate(player)

func _dispatch_role_to_player(player: PlayerState) -> void:
	if player.peer_id == multiplayer.get_unique_id():
		_receive_private_role(int(player.role))
	elif not _is_offline_synthetic_peer(player.peer_id):
		_receive_private_role.rpc_id(player.peer_id, int(player.role))

func _dispatch_heretic_teammate(player: PlayerState) -> void:
	var teammate := _heretic_teammate_for(player.peer_id)
	if teammate == null:
		return
	if player.peer_id == multiplayer.get_unique_id():
		_receive_private_heretic_teammate(teammate.peer_id, teammate.display_name)
	elif not _is_offline_synthetic_peer(player.peer_id):
		_receive_private_heretic_teammate.rpc_id(
			player.peer_id,
			teammate.peer_id,
			teammate.display_name,
		)

func _heretic_teammate_for(peer_id: int) -> PlayerState:
	if _session == null:
		return null
	var actor := _session.get_player(peer_id)
	if actor == null or actor.role != PlayerState.Role.HERETIC:
		return null
	for player in _session.players:
		if player.peer_id != peer_id and player.role == PlayerState.Role.HERETIC:
			return player
	return null

func _server_acknowledge_role(peer_id: int) -> void:
	if not multiplayer.is_server() or _session == null:
		return
	var player := _session.get_player(peer_id)
	if player == null or not player.alive:
		return
	_role_acknowledged[peer_id] = true
	if _role_acknowledged.size() >= _living_player_count():
		_start_god_intro()

func _start_god_intro() -> void:
	if GameManager.phase == GameManager.MatchPhase.GOD_INTRO:
		return
	_broadcast_phase(GameManager.MatchPhase.GOD_INTRO)

func _start_night() -> void:
	_reset_night_actions()
	_broadcast_phase(GameManager.MatchPhase.NIGHT_START)

func _advance_night_phase() -> void:
	if not multiplayer.is_server() or _session == null:
		return
	var next_phase := NightPhaseRules.next_action_phase(GameManager.phase)
	match next_phase:
		GameManager.MatchPhase.HERETIC_ACTION:
			var decider := _choose_heretic_decider()
			_sync_heretic_decider.rpc(decider)
			_broadcast_phase(next_phase)
		GameManager.MatchPhase.HEALER_ACTION:
			_prepare_first_night_priest_warning()
			_broadcast_phase(next_phase)
		GameManager.MatchPhase.INQUISITOR_ACTION:
			_broadcast_phase(next_phase)
		GameManager.MatchPhase.NIGHT_RESOLUTION:
			_broadcast_phase(GameManager.MatchPhase.NIGHT_RESOLUTION)
			_resolve_night()
		_:
			return

func _choose_heretic_decider() -> int:
	if _session == null:
		return 0
	var living_heretics: Array[int] = []
	for player in _session.players:
		if player.alive and player.role == PlayerState.Role.HERETIC:
			living_heretics.append(player.peer_id)
	living_heretics.sort()
	if living_heretics.is_empty():
		return 0
	var index := (maxi(1, GameManager.round_number) - 1) % living_heretics.size()
	return living_heretics[index]

func _prepare_first_night_priest_warning() -> void:
	if GameManager.round_number != 1 or _session == null:
		return
	var victim_peer_id := _current_heretic_target()
	if victim_peer_id <= 0:
		return
	for player in _session.players:
		if not player.alive or player.role != PlayerState.Role.HEALER:
			continue
		_healer_target_peer_id = victim_peer_id
		if player.peer_id == multiplayer.get_unique_id():
			_receive_private_priest_warning(victim_peer_id)
		elif not _is_offline_synthetic_peer(player.peer_id):
			_receive_private_priest_warning.rpc_id(player.peer_id, victim_peer_id)
		return

func _server_submit_night_action(actor_peer_id: int, target_peer_id: int) -> void:
	if not multiplayer.is_server() or _session == null:
		return
	var required_role := NightPhaseRules.role_for_phase(GameManager.phase)
	if required_role == PlayerState.Role.UNASSIGNED:
		_send_night_action_result(actor_peer_id, false, target_peer_id)
		return
	if not _night_role_specific_validation(actor_peer_id, target_peer_id, required_role):
		_send_night_action_result(actor_peer_id, false, target_peer_id)
		return
	if not NightActionRules.can_target(
		_session.players,
		actor_peer_id,
		target_peer_id,
		required_role,
	):
		_send_night_action_result(actor_peer_id, false, target_peer_id)
		return
	match required_role:
		PlayerState.Role.HERETIC:
			_heretic_targets.clear()
			_heretic_targets[actor_peer_id] = target_peer_id
		PlayerState.Role.HEALER:
			_healer_target_peer_id = target_peer_id
		PlayerState.Role.INQUISITOR:
			_inquisitor_target_peer_id = target_peer_id
	_send_night_action_result(actor_peer_id, true, target_peer_id)
	night_action_accepted.emit(actor_peer_id, target_peer_id)

func _night_role_specific_validation(
	actor_peer_id: int,
	target_peer_id: int,
	required_role: PlayerState.Role
) -> bool:
	if required_role == PlayerState.Role.HERETIC:
		return actor_peer_id == current_heretic_decider_peer_id
	if required_role == PlayerState.Role.HEALER:
		if GameManager.round_number == 1:
			return false
		if actor_peer_id == target_peer_id and _healer_self_save_used:
			return false
	if required_role == PlayerState.Role.INQUISITOR and GameManager.round_number == 1:
		return false
	return true

func _send_night_action_result(actor_peer_id: int, accepted: bool, target_peer_id: int) -> void:
	if multiplayer.multiplayer_peer == null or actor_peer_id == multiplayer.get_unique_id():
		_receive_night_action_result(accepted, target_peer_id)
	elif not _is_offline_synthetic_peer(actor_peer_id):
		_receive_night_action_result.rpc_id(actor_peer_id, accepted, target_peer_id)

func _current_phase_has_all_actions(role: PlayerState.Role) -> bool:
	match role:
		PlayerState.Role.HERETIC:
			return _current_heretic_target() > 0
		PlayerState.Role.HEALER:
			return GameManager.round_number == 1 or _healer_target_peer_id != 0
		PlayerState.Role.INQUISITOR:
			return GameManager.round_number == 1 or _inquisitor_target_peer_id != 0
		_:
			return false

func _current_heretic_target() -> int:
	if current_heretic_decider_peer_id > 0 and _heretic_targets.has(current_heretic_decider_peer_id):
		return int(_heretic_targets[current_heretic_decider_peer_id])
	for raw_target in _heretic_targets.values():
		return int(raw_target)
	return 0

func _auto_choose_heretic_target_if_needed() -> void:
	if _session == null or _current_heretic_target() > 0:
		return
	var candidates: Array[int] = []
	for player in _session.players:
		if player.alive and player.role != PlayerState.Role.HERETIC:
			candidates.append(player.peer_id)
	if candidates.is_empty() or current_heretic_decider_peer_id <= 0:
		return
	var chosen := candidates[_session.rng.randi_range(0, candidates.size() - 1)]
	_heretic_targets[current_heretic_decider_peer_id] = chosen

func _consume_healer_self_save_if_needed() -> void:
	if _session == null or GameManager.round_number <= 1 or _healer_target_peer_id <= 0:
		return
	for player in _session.players:
		if player.alive and player.role == PlayerState.Role.HEALER:
			if player.peer_id == _healer_target_peer_id:
				_healer_self_save_used = true
			return

func _resolve_night() -> void:
	var targets: Array[int] = []
	var heretic_target := _current_heretic_target()
	if heretic_target > 0:
		targets.append(heretic_target)
	var first_night := GameManager.round_number == 1
	var result := NightResolver.resolve_many(
		_session.players,
		targets,
		_healer_target_peer_id,
		_inquisitor_target_peer_id,
		first_night,
	)
	var priest_saved := (
		heretic_target > 0
		and _healer_target_peer_id == heretic_target
		and _living_role_count(PlayerState.Role.HEALER) > 0
	)
	_sync_night_resolution.rpc(result.killed_peer_ids)
	_sync_public_night_report.rpc(result.killed_peer_ids, priest_saved, first_night)
	_dispatch_investigation_result(result)
	_broadcast_phase(GameManager.MatchPhase.DAY_ANNOUNCEMENT)

func _dispatch_investigation_result(result: NightResolver.NightResult) -> void:
	if result.investigation_target_peer_id == 0:
		return
	for player in _session.players:
		if player.alive and player.role == PlayerState.Role.INQUISITOR:
			if player.peer_id == multiplayer.get_unique_id():
				_receive_private_investigation(
					result.investigation_target_peer_id,
					result.investigation_is_heretic,
				)
			elif not _is_offline_synthetic_peer(player.peer_id):
				_receive_private_investigation.rpc_id(
					player.peer_id,
					result.investigation_target_peer_id,
					result.investigation_is_heretic,
				)
			return

func _server_submit_vote(voter_peer_id: int, target_peer_id: int) -> void:
	if not multiplayer.is_server() or _session == null:
		return
	if GameManager.phase != GameManager.MatchPhase.VOTING:
		return
	if not VoteRules.can_vote(_session.players, voter_peer_id, target_peer_id):
		return
	_votes[voter_peer_id] = target_peer_id
	vote_accepted.emit(voter_peer_id, target_peer_id)

func _valid_vote_count() -> int:
	if _session == null:
		return 0
	var count := 0
	for raw_voter_id in _votes.keys():
		var voter_id := int(raw_voter_id)
		var target_peer_id := int(_votes[raw_voter_id])
		if VoteRules.can_vote(_session.players, voter_id, target_peer_id):
			count += 1
	return count

func _resolve_vote(_use_partial_votes: bool = false) -> void:
	if _session == null:
		return
	var top_targets := VoteRules.top_targets(_session.players, _votes)
	var tied := top_targets.size() > 1
	var sacrificed_peer_id := 0
	if top_targets.size() == 1:
		sacrificed_peer_id = top_targets[0]
	elif tied:
		sacrificed_peer_id = top_targets[_session.rng.randi_range(0, top_targets.size() - 1)]
	var was_heretic := false
	if sacrificed_peer_id > 0:
		var sacrificed := _session.get_player(sacrificed_peer_id)
		was_heretic = sacrificed != null and sacrificed.role == PlayerState.Role.HERETIC
		_session.sacrifice(sacrificed_peer_id)
	_sync_sacrifice.rpc(sacrificed_peer_id, tied, was_heretic)
	_broadcast_phase(GameManager.MatchPhase.SACRIFICE)

func _finish_after_day_announcement() -> void:
	if _session == null:
		return
	var winner := _session.winner()
	if not winner.is_empty():
		_end_match(winner)
		return
	_broadcast_phase(GameManager.MatchPhase.DAY_DISCUSSION)

func _finish_after_sacrifice() -> void:
	if _session == null:
		return
	var winner := _session.winner()
	if not winner.is_empty():
		_end_match(winner)
		return
	GameManager.round_number += 1
	_start_night()

func _end_match(winner: StringName) -> void:
	_sync_match_end.rpc(str(winner))

func _living_player_count() -> int:
	return 0 if _session == null else _session.living_players().size()

func _living_role_count(role: PlayerState.Role) -> int:
	if _session == null:
		return 0
	var count := 0
	for player in _session.players:
		if player.alive and player.role == role:
			count += 1
	return count

func _broadcast_phase(phase_value: GameManager.MatchPhase) -> void:
	_sync_phase.rpc(int(phase_value), GameManager.round_number)
	_arm_phase_timeout(phase_value)

func _arm_phase_timeout(phase_value: GameManager.MatchPhase) -> void:
	if not multiplayer.is_server() or not NetworkManager.is_host:
		_clear_phase_timeout()
		return
	_phase_deadline_phase = int(phase_value)
	_phase_deadline_ms = PhaseTimeoutPolicy.deadline_ms(phase_value, Time.get_ticks_msec())
	if _phase_deadline_ms == 0:
		_phase_deadline_phase = -1

func _clear_phase_timeout() -> void:
	_phase_deadline_ms = 0
	_phase_deadline_phase = -1

func _handle_phase_timeout(expired_phase: GameManager.MatchPhase) -> void:
	if _session == null or GameManager.phase != expired_phase:
		return
	match expired_phase:
		GameManager.MatchPhase.ROLE_REVEAL:
			_start_god_intro()
		GameManager.MatchPhase.GOD_INTRO:
			_start_night()
		GameManager.MatchPhase.NIGHT_START:
			_advance_night_phase()
		GameManager.MatchPhase.HERETIC_ACTION:
			_auto_choose_heretic_target_if_needed()
			_advance_night_phase()
		GameManager.MatchPhase.HEALER_ACTION:
			_consume_healer_self_save_if_needed()
			_advance_night_phase()
		GameManager.MatchPhase.INQUISITOR_ACTION:
			_advance_night_phase()
		GameManager.MatchPhase.DAY_ANNOUNCEMENT:
			_finish_after_day_announcement()
		GameManager.MatchPhase.DAY_DISCUSSION:
			request_begin_voting()
		GameManager.MatchPhase.VOTING:
			_resolve_vote(true)
		GameManager.MatchPhase.SACRIFICE:
			_finish_after_sacrifice()

func _reset_night_actions() -> void:
	_heretic_targets.clear()
	_healer_target_peer_id = 0
	_inquisitor_target_peer_id = 0
	current_heretic_decider_peer_id = 0

func _reset_for_rematch() -> void:
	local_role = PlayerState.Role.UNASSIGNED
	local_heretic_teammate_peer_id = 0
	local_heretic_teammate_name = ""
	current_heretic_decider_peer_id = 0
	public_winner = &""
	_session = null
	_roles_dispatched = false
	_role_acknowledged.clear()
	_votes.clear()
	_healer_self_save_used = false
	_reset_night_actions()
	_clear_phase_timeout()
	_initialize_public_alive()
	GameManager.round_number = 0
	GameManager.set_phase(GameManager.MatchPhase.READY)

func _apply_peer_disconnect(peer_id: int) -> bool:
	if _session == null:
		return false
	var player := _session.get_player(peer_id)
	if player == null:
		return false
	player.alive = false
	public_alive_by_peer[peer_id] = false
	_role_acknowledged.erase(peer_id)
	_heretic_targets.erase(peer_id)
	for raw_actor_id in _heretic_targets.keys():
		if int(_heretic_targets[raw_actor_id]) == peer_id:
			_heretic_targets.erase(raw_actor_id)
	if _healer_target_peer_id == peer_id:
		_healer_target_peer_id = 0
	if _inquisitor_target_peer_id == peer_id:
		_inquisitor_target_peer_id = 0
	_votes.erase(peer_id)
	for raw_voter_id in _votes.keys():
		if int(_votes[raw_voter_id]) == peer_id:
			_votes.erase(raw_voter_id)
	return true

func _resume_after_disconnect() -> void:
	if _session == null or GameManager.phase == GameManager.MatchPhase.MATCH_END:
		return
	var winner := _session.winner()
	if not winner.is_empty():
		_end_match(winner)
		return
	if GameManager.phase == GameManager.MatchPhase.ROLE_REVEAL:
		if _role_acknowledged.size() >= _living_player_count():
			_start_god_intro()

func _is_offline_synthetic_peer(peer_id: int) -> bool:
	return multiplayer.multiplayer_peer is OfflineMultiplayerPeer and peer_id != multiplayer.get_unique_id()

@rpc("authority", "call_remote", "reliable")
func _receive_private_role(role_value: int) -> void:
	if role_value <= PlayerState.Role.UNASSIGNED or role_value > PlayerState.Role.INQUISITOR:
		return
	local_role = role_value as PlayerState.Role
	if local_role != PlayerState.Role.HERETIC:
		local_heretic_teammate_peer_id = 0
		local_heretic_teammate_name = ""
	if public_alive_by_peer.is_empty():
		_initialize_public_alive()
	private_role_received.emit(int(local_role))

@rpc("authority", "call_remote", "reliable")
func _receive_private_heretic_teammate(peer_id: int, display_name: String) -> void:
	if local_role != PlayerState.Role.HERETIC or peer_id <= 0:
		return
	var clean_name := display_name.strip_edges()
	if clean_name.is_empty():
		return
	local_heretic_teammate_peer_id = peer_id
	local_heretic_teammate_name = clean_name
	private_heretic_teammate_received.emit(peer_id, clean_name)

@rpc("authority", "call_remote", "reliable")
func _receive_private_priest_warning(target_peer_id: int) -> void:
	if local_role != PlayerState.Role.HEALER or target_peer_id <= 0:
		return
	private_priest_warning_received.emit(target_peer_id)

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
func _sync_phase(phase_value: int, round_value: int = -1) -> void:
	if phase_value < GameManager.MatchPhase.BOOT or phase_value > GameManager.MatchPhase.MATCH_END:
		return
	if round_value >= 0:
		GameManager.round_number = round_value
	GameManager.set_phase(phase_value)
	_local_phase_started_ms = Time.get_ticks_msec()
	_local_phase_duration_ms = PhaseTimeoutPolicy.timeout_ms_for_phase(GameManager.phase)
	phase_synced.emit(phase_value)
	phase_timing_synced.emit(phase_value, _local_phase_duration_ms)

@rpc("authority", "call_local", "reliable")
func _sync_heretic_decider(peer_id: int) -> void:
	current_heretic_decider_peer_id = peer_id
	heretic_decider_changed.emit(peer_id)

@rpc("authority", "call_remote", "reliable")
func _receive_night_action_result(accepted: bool, target_peer_id: int) -> void:
	night_action_result_received.emit(accepted, target_peer_id)

@rpc("authority", "call_local", "reliable")
func _sync_night_resolution(killed_peer_ids: Array[int]) -> void:
	for peer_id in killed_peer_ids:
		public_alive_by_peer[int(peer_id)] = false
	night_resolution_received.emit(killed_peer_ids)

@rpc("authority", "call_local", "reliable")
func _sync_public_night_report(
	killed_peer_ids: Array[int],
	priest_saved: bool,
	first_night: bool
) -> void:
	last_night_killed_peer_ids.clear()
	for peer_id in killed_peer_ids:
		last_night_killed_peer_ids.append(int(peer_id))
	last_night_priest_saved = priest_saved
	last_night_was_first = first_night
	night_public_report_received.emit(
		last_night_killed_peer_ids,
		priest_saved,
		first_night,
	)

@rpc("authority", "call_local", "reliable")
func _sync_sacrifice(sacrificed_peer_id: int, tied: bool, was_heretic: bool) -> void:
	if sacrificed_peer_id > 0:
		public_alive_by_peer[sacrificed_peer_id] = false
	last_sacrificed_peer_id = sacrificed_peer_id
	last_sacrifice_was_tie = tied
	last_sacrifice_was_heretic = was_heretic
	vote_resolution_received.emit(sacrificed_peer_id, tied)
	sacrifice_reveal_received.emit(sacrificed_peer_id, tied, was_heretic)

@rpc("authority", "call_local", "reliable")
func _sync_match_end(winner_value: String) -> void:
	var winner := StringName(winner_value)
	if winner not in [&"faithful", &"heretics"]:
		return
	public_winner = winner
	_clear_phase_timeout()
	GameManager.end_match(winner)
	match_end_received.emit(winner)

@rpc("authority", "call_local", "reliable")
func _sync_rematch() -> void:
	_reset_for_rematch()
	rematch_received.emit()

@rpc("authority", "call_remote", "reliable")
func _receive_private_investigation(target_peer_id: int, is_heretic: bool) -> void:
	private_investigation_received.emit(target_peer_id, is_heretic)

func _on_peer_left(peer_id: int) -> void:
	public_alive_by_peer[peer_id] = false
	if not multiplayer.is_server():
		return
	if _apply_peer_disconnect(peer_id):
		_resume_after_disconnect()

func _on_lobby_state_changed(state: StringName) -> void:
	if state in [&"steam_ready", &"offline", &"host_disconnected", &"connection_failed"]:
		reset()
