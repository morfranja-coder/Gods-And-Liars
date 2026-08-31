extends Node

signal practice_started
signal practice_stopped

const HUMAN_PEER_ID := 1
const BOT_COUNT := 7
const TOTAL_PLAYERS := 8
const BOT_NAME_PREFIX := "Acólito"

var active: bool = false
var _bot_peer_ids: Array[int] = []

func _ready() -> void:
	MatchAuthority.phase_synced.connect(_on_phase_synced)
	MatchAuthority.rematch_received.connect(_on_rematch_received)

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
		MatchAuthority.practice_acknowledge_role(peer_id)

func _play_bot_night_actions() -> void:
	if not active or not NightPhaseRules.is_action_phase(GameManager.phase):
		return
	var required_role := NightPhaseRules.role_for_phase(GameManager.phase)
	for peer_id in _bot_peer_ids:
		if not MatchAuthority.is_peer_publicly_alive(peer_id):
			continue
		if MatchAuthority.server_role_for_peer(peer_id) != required_role:
			continue
		var target_peer_id := MatchAuthority.practice_pick_night_target(peer_id)
		if target_peer_id > 0:
			MatchAuthority.practice_submit_night_action(peer_id, target_peer_id)

func _play_bot_votes() -> void:
	if not active or GameManager.phase != GameManager.MatchPhase.VOTING:
		return
	for peer_id in _bot_peer_ids:
		if not MatchAuthority.is_peer_publicly_alive(peer_id):
			continue
		var target_peer_id := MatchAuthority.practice_pick_vote_target(peer_id)
		if target_peer_id > 0:
			MatchAuthority.practice_submit_vote(peer_id, target_peer_id)

func _on_rematch_received() -> void:
	if active:
		call_deferred("_begin_rematch")

func _begin_rematch() -> void:
	if active:
		MatchAuthority.begin_role_reveal()
