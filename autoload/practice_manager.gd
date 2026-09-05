extends Node

signal practice_started
signal practice_stopped

const HUMAN_PEER_ID := 1
const BOT_COUNT := 7
const BOT_NAME_PREFIX := "Acólito"

var active: bool = false
var forced_human_role: PlayerState.Role = PlayerState.Role.UNASSIGNED
var _bot_peer_ids: Array[int] = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	MatchAuthority.phase_synced.connect(_on_phase_synced)

func start_seven_bot_match(
	forced_role: PlayerState.Role = PlayerState.Role.UNASSIGNED
) -> void:
	stop_practice()
	forced_human_role = forced_role
	_rng.randomize()
	active = true
	_setup_offline_host()
	_seed_roster()
	practice_started.emit()

func stop_practice() -> void:
	if not active and multiplayer.multiplayer_peer == null:
		forced_human_role = PlayerState.Role.UNASSIGNED
		return
	active = false
	forced_human_role = PlayerState.Role.UNASSIGNED
	_bot_peer_ids.clear()
	MatchAuthority.reset()
	GameManager.reset_match()
	NetworkManager.reset()
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer = null
	practice_stopped.emit()

func role_for_practice_command(command: String) -> PlayerState.Role:
	match command.strip_edges().to_upper():
		"PRACTICA1_HEREJE":
			return PlayerState.Role.HERETIC
		"PRACTICA1_FIEL":
			return PlayerState.Role.FAITHFUL
		"PRACTICA1_SACERDOTE":
			return PlayerState.Role.HEALER
		"PRACTICA1_INQUISIDOR":
			return PlayerState.Role.INQUISITOR
		_:
			return PlayerState.Role.UNASSIGNED

func bot_peer_ids() -> Array[int]:
	return _bot_peer_ids.duplicate()

func is_bot(peer_id: int) -> bool:
	return peer_id in _bot_peer_ids

func _setup_offline_host() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	NetworkManager.is_host = true
	NetworkManager.lobby_id = 1
	NetworkManager.lobby_started = true

func _seed_roster() -> void:
	NetworkManager.lobby_started = false
	NetworkManager.register_peer(HUMAN_PEER_ID, 990001, "Vos", 0)
	for index in range(BOT_COUNT):
		var peer_id := index + 2
		_bot_peer_ids.append(peer_id)
		NetworkManager.register_peer(
			peer_id,
			990001 + peer_id,
			"%s %d" % [BOT_NAME_PREFIX, index + 1],
			index + 1,
		)
	NetworkManager.lobby_started = true

func _on_phase_synced(phase_value: int) -> void:
	if not active:
		return
	match phase_value:
		GameManager.MatchPhase.ROLE_REVEAL:
			_apply_forced_human_role()
			call_deferred("_acknowledge_bot_roles")
		GameManager.MatchPhase.HERETIC_ACTION, \
		GameManager.MatchPhase.HEALER_ACTION, \
		GameManager.MatchPhase.INQUISITOR_ACTION:
			call_deferred("_play_bot_night_actions")
		GameManager.MatchPhase.VOTING:
			call_deferred("_play_bot_votes")

func _apply_forced_human_role() -> void:
	if forced_human_role == PlayerState.Role.UNASSIGNED:
		return
	var session: MatchSession = MatchAuthority.get("_session") as MatchSession
	if session == null:
		return
	var human := session.get_player(HUMAN_PEER_ID)
	if human == null or human.role == forced_human_role:
		return
	var swap_player: PlayerState = null
	for player in session.players:
		if player.peer_id != HUMAN_PEER_ID and player.role == forced_human_role:
			swap_player = player
			break
	if swap_player == null:
		return
	var original_human_role: PlayerState.Role = human.role
	human.role = forced_human_role
	swap_player.role = original_human_role

func _acknowledge_bot_roles() -> void:
	if not active or GameManager.phase != GameManager.MatchPhase.ROLE_REVEAL:
		return
	for peer_id in _bot_peer_ids:
		MatchAuthority._server_acknowledge_role(peer_id)

func _play_bot_night_actions() -> void:
	if not active or not NightPhaseRules.is_action_phase(GameManager.phase):
		return
	var required_role := NightPhaseRules.role_for_phase(GameManager.phase)
	for peer_id in _bot_peer_ids:
		if not _bot_can_act(peer_id, required_role):
			continue
		var target_peer_id := _pick_night_target(peer_id, required_role)
		if target_peer_id > 0:
			MatchAuthority._server_submit_night_action(peer_id, target_peer_id)

func _play_bot_votes() -> void:
	if not active or GameManager.phase != GameManager.MatchPhase.VOTING:
		return
	for peer_id in _bot_peer_ids:
		if not MatchAuthority.is_peer_publicly_alive(peer_id):
			continue
		var target_peer_id := _pick_other_living_peer(peer_id)
		if target_peer_id > 0:
			MatchAuthority._server_submit_vote(peer_id, target_peer_id)

func _bot_can_act(peer_id: int, required_role: PlayerState.Role) -> bool:
	if not MatchAuthority.is_peer_publicly_alive(peer_id):
		return false
	return MatchAuthority.server_role_for_peer(peer_id) == required_role

func _pick_night_target(peer_id: int, role: PlayerState.Role) -> int:
	if role == PlayerState.Role.HEALER:
		return _pick_random_other_living_peer(peer_id)
	if role == PlayerState.Role.HERETIC:
		return _pick_living_non_heretic(peer_id)
	return _pick_other_living_peer(peer_id)

func _pick_random_other_living_peer(actor_peer_id: int) -> int:
	var candidates: Array[int] = []
	for raw_peer_id in NetworkManager.peers.keys():
		var peer_id := int(raw_peer_id)
		if peer_id == actor_peer_id:
			continue
		if MatchAuthority.is_peer_publicly_alive(peer_id):
			candidates.append(peer_id)
	if candidates.is_empty():
		return 0
	return candidates[_rng.randi_range(0, candidates.size() - 1)]

func _pick_living_non_heretic(actor_peer_id: int) -> int:
	for raw_peer_id in NetworkManager.peers.keys():
		var peer_id := int(raw_peer_id)
		if peer_id == actor_peer_id or not MatchAuthority.is_peer_publicly_alive(peer_id):
			continue
		if MatchAuthority.server_role_for_peer(peer_id) != PlayerState.Role.HERETIC:
			return peer_id
	return 0

func _pick_other_living_peer(actor_peer_id: int) -> int:
	for raw_peer_id in NetworkManager.peers.keys():
		var peer_id := int(raw_peer_id)
		if peer_id == actor_peer_id:
			continue
		if MatchAuthority.is_peer_publicly_alive(peer_id):
			return peer_id
	return 0
