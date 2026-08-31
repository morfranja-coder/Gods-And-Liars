class_name MatchSnapshot
extends RefCounted

const VERSION := 1

var version: int = VERSION
var phase: int = int(GameManager.MatchPhase.BOOT)
var round_number: int = 0
var phase_remaining_ms: int = 0
var public_winner: String = ""
var roles_dispatched: bool = false
var players: Array[Dictionary] = []
var role_acknowledged: Dictionary = {}
var heretic_targets: Dictionary = {}
var healer_target_peer_id: int = 0
var inquisitor_target_peer_id: int = 0
var votes: Dictionary = {}

static func from_runtime(
	session: MatchSession,
	current_phase: int,
	current_round: int,
	remaining_ms: int,
	winner: StringName,
	roles_were_dispatched: bool,
	role_acks: Dictionary,
	heretic_action_targets: Dictionary,
	healer_target: int,
	inquisitor_target: int,
	current_votes: Dictionary,
) -> MatchSnapshot:
	if session == null:
		return null
	var snapshot := MatchSnapshot.new()
	snapshot.phase = current_phase
	snapshot.round_number = current_round
	snapshot.phase_remaining_ms = maxi(0, remaining_ms)
	snapshot.public_winner = str(winner)
	snapshot.roles_dispatched = roles_were_dispatched
	snapshot.players = _serialize_players(session.players)
	snapshot.role_acknowledged = _normalize_dictionary(role_acks)
	snapshot.heretic_targets = _normalize_dictionary(heretic_action_targets)
	snapshot.healer_target_peer_id = healer_target
	snapshot.inquisitor_target_peer_id = inquisitor_target
	snapshot.votes = _normalize_dictionary(current_votes)
	return snapshot if snapshot.is_valid() else null

static func from_dictionary(data: Dictionary) -> MatchSnapshot:
	var snapshot := MatchSnapshot.new()
	snapshot.version = int(data.get("version", 0))
	snapshot.phase = int(data.get("phase", -1))
	snapshot.round_number = int(data.get("round_number", -1))
	snapshot.phase_remaining_ms = int(data.get("phase_remaining_ms", -1))
	snapshot.public_winner = str(data.get("public_winner", ""))
	snapshot.roles_dispatched = bool(data.get("roles_dispatched", false))
	var raw_players = data.get("players", [])
	if raw_players is Array:
		for raw_player in raw_players:
			if raw_player is Dictionary:
				snapshot.players.append(raw_player.duplicate(true))
	snapshot.role_acknowledged = _normalize_dictionary(
		data.get("role_acknowledged", {})
	)
	snapshot.heretic_targets = _normalize_dictionary(data.get("heretic_targets", {}))
	snapshot.healer_target_peer_id = int(data.get("healer_target_peer_id", 0))
	snapshot.inquisitor_target_peer_id = int(data.get("inquisitor_target_peer_id", 0))
	snapshot.votes = _normalize_dictionary(data.get("votes", {}))
	return snapshot if snapshot.is_valid() else null

static func from_json(json_text: String) -> MatchSnapshot:
	var parsed = JSON.parse_string(json_text)
	return from_dictionary(parsed) if parsed is Dictionary else null

func to_dictionary() -> Dictionary:
	return {
		"version": version,
		"phase": phase,
		"round_number": round_number,
		"phase_remaining_ms": phase_remaining_ms,
		"public_winner": public_winner,
		"roles_dispatched": roles_dispatched,
		"players": players.duplicate(true),
		"role_acknowledged": role_acknowledged.duplicate(true),
		"heretic_targets": heretic_targets.duplicate(true),
		"healer_target_peer_id": healer_target_peer_id,
		"inquisitor_target_peer_id": inquisitor_target_peer_id,
		"votes": votes.duplicate(true),
	}

func to_json() -> String:
	return JSON.stringify(to_dictionary())

func restore_session() -> MatchSession:
	if not is_valid():
		return null
	var session := MatchSession.new()
	for data in players:
		var peer_id := int(data.get("peer_id", 0))
		if not session.add_player(
			peer_id,
			int(data.get("steam_id", 0)),
			str(data.get("display_name", "")),
		):
			return null
		var player := session.get_player(peer_id)
		player.seat_id = int(data.get("seat_id", -1))
		player.role = int(data.get("role", int(PlayerState.Role.UNASSIGNED))) as PlayerState.Role
		player.alive = bool(data.get("alive", true))
		player.ready = bool(data.get("ready", false))
		player.selected_target_peer_id = int(data.get("selected_target_peer_id", 0))
		player.vote_target_peer_id = int(data.get("vote_target_peer_id", 0))
	return session

func is_valid() -> bool:
	if version != VERSION or not _valid_phase(phase):
		return false
	if round_number < 0 or phase_remaining_ms < 0:
		return false
	if players.size() != MatchSession.MAX_PLAYERS:
		return false
	return _players_are_valid(players)

static func _players_are_valid(source: Array[Dictionary]) -> bool:
	var peer_ids: Dictionary = {}
	var steam_ids: Dictionary = {}
	var seat_ids: Dictionary = {}
	for data in source:
		if not _player_data_is_valid(data):
			return false
		var peer_id := int(data.get("peer_id", 0))
		var steam_id := int(data.get("steam_id", 0))
		var seat_id := int(data.get("seat_id", -1))
		if peer_ids.has(peer_id) or steam_ids.has(steam_id) or seat_ids.has(seat_id):
			return false
		peer_ids[peer_id] = true
		steam_ids[steam_id] = true
		seat_ids[seat_id] = true
	return true

static func _player_data_is_valid(data: Dictionary) -> bool:
	var peer_id := int(data.get("peer_id", 0))
	var steam_id := int(data.get("steam_id", 0))
	var seat_id := int(data.get("seat_id", -1))
	var role := int(data.get("role", -1))
	if peer_id <= 0 or steam_id <= 0 or not SeatAllocator.is_valid_seat(seat_id):
		return false
	return (
		role >= int(PlayerState.Role.UNASSIGNED)
		and role <= int(PlayerState.Role.INQUISITOR)
	)

static func _serialize_players(source: Array[PlayerState]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for player in source:
		result.append({
			"peer_id": player.peer_id,
			"steam_id": player.steam_id,
			"display_name": player.display_name,
			"seat_id": player.seat_id,
			"role": int(player.role),
			"alive": player.alive,
			"ready": player.ready,
			"selected_target_peer_id": player.selected_target_peer_id,
			"vote_target_peer_id": player.vote_target_peer_id,
		})
	result.sort_custom(_player_data_precedes)
	return result

static func _player_data_precedes(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("peer_id", 0)) < int(b.get("peer_id", 0))

static func _normalize_dictionary(source) -> Dictionary:
	var result: Dictionary = {}
	if not source is Dictionary:
		return result
	for raw_key in source.keys():
		var key := int(raw_key)
		var value = source[raw_key]
		if value is bool:
			result[key] = value
		elif value is int or value is float or str(value).is_valid_int():
			result[key] = int(value)
	return result

static func _valid_phase(value: int) -> bool:
	return (
		value >= int(GameManager.MatchPhase.BOOT)
		and value <= int(GameManager.MatchPhase.MATCH_END)
	)
