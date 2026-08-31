extends Node

signal practice_started
signal practice_stopped

const HUMAN_PEER_ID := 1
const BOT_COUNT := 7
const BOT_NAME_PREFIX := "Acólito"

var active: bool = false
var _bot_peer_ids: Array[int] = []

func _ready() -> void:
	MatchAuthority.phase_synced.connect(_on_phase_synced)

func start_seven_bot_match() -> void:
	stop_practice()
	active = true
	_setup_offline_host()
	_seed_roster()
	practice_started.emit()

func stop_practice() -> void:
	if not active and multiplayer.multiplayer_peer == null:
		return
	active = false
	_bot_peer_ids.clear()
	MatchAuthority.reset()
	GameManager.reset_match()
	NetworkManager.reset()
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer = null
	practice_stopped.emit()

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
			call_deferred("_acknowledge_bot_roles")
		GameManager.MatchPhase.HERETIC_ACTION, \
		GameManager.MatchPhase.HEALER_ACTION, \
		GameManager.MatchPhase.INQUISITOR_ACTION:
			call_deferred("_play_bot_night_actions")
		GameManager.MatchPhase.VOTING:
			call_deferred("_play_bot_votes")

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
		return _pick_living_peer()
	if role == PlayerState.Role.HERETIC:
		return _pick_living_non_heretic(peer_id)
	return _pick_other_living_peer(peer_id)

func _pick_living_peer() -> int:
	for raw_peer_id in NetworkManager.peers.keys():
		var peer_id := int(raw_peer_id)
		if MatchAuthority.is_peer_publicly_alive(peer_id):
			return peer_id
	return 0

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
