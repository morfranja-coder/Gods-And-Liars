extends Node

signal queue_state_changed(state: StringName)
signal search_scope_changed(distance_tier: int)
signal match_composition_found(party_ids: Array[int])
signal match_candidate_found(lobby_id: int, open_slots: int)
signal queue_error(message: String)

const STATE_IDLE := &"idle"
const STATE_SEARCHING := &"searching"
const STATE_RESERVING := &"reserving"
const STATE_HOSTING := &"hosting"
const STATE_MATCH_FOUND := &"match_found"

const SEARCH_INTERVAL_MS := 2500
const ANCHOR_BASE_DELAY_MS := 3000
const ANCHOR_JITTER_MS := 3000
const GAME_TAG_KEY := "game"
const GAME_TAG_VALUE := "GodsAndLiarsMVP"
const LOBBY_KIND_KEY := "kind"
const LOBBY_KIND_MATCH := "match"
const MATCH_STATE_KEY := "match_state"
const MATCH_STATE_OPEN := "open"
const OPEN_SLOTS_KEY := "open_slots"
const STEAM_LOBBY_COMPARISON_EQUAL := 0

var state: StringName = STATE_IDLE
var local_party_size: int = 1
var queue_started_ms: int = 0
var current_distance_tier: int = QuickMatchRules.DISTANCE_CLOSE
var _steam: Object = null
var _search_pending: bool = false
var _last_search_ms: int = 0
var _anchor_after_ms: int = ANCHOR_BASE_DELAY_MS
var _candidate_lobby_id: int = 0
var _steam_search_enabled: bool = false

func _ready() -> void:
	Steamworks.steam_ready.connect(_bind_steam_callbacks)
	Steamworks.steam_unavailable.connect(_on_steam_unavailable)
	PartyManager.match_target_changed.connect(_on_party_match_target_changed)
	NetworkManager.party_reservation_result.connect(_on_party_reservation_result)
	NetworkManager.lobby_state_changed.connect(_on_network_lobby_state_changed)
	if Steamworks.initialized:
		_bind_steam_callbacks()

func _process(_delta: float) -> void:
	if state != STATE_SEARCHING or not _steam_search_enabled:
		return
	var elapsed_ms: int = maxi(0, Time.get_ticks_msec() - queue_started_ms)
	var next_tier: int = QuickMatchRules.distance_tier_for_elapsed(elapsed_ms)
	if next_tier != current_distance_tier:
		current_distance_tier = next_tier
		search_scope_changed.emit(current_distance_tier)
		_request_match_lobbies(true)
	var now_ms := Time.get_ticks_msec()
	if not _search_pending and now_ms - _last_search_ms >= SEARCH_INTERVAL_MS:
		_request_match_lobbies()
	if elapsed_ms >= _anchor_after_ms and NetworkManager.lobby_id == 0 and not _search_pending:
		_host_anchor_match()

func _bind_steam_callbacks() -> void:
	_steam = Steamworks.get_api()
	if _steam == null:
		return
	if _steam.has_signal("lobby_match_list") and not _steam.is_connected(
		"lobby_match_list",
		_on_lobby_match_list,
	):
		_steam.connect("lobby_match_list", _on_lobby_match_list)

func start_party_quick_match() -> bool:
	if not PartyManager.can_queue():
		queue_error.emit("Solo el líder de un Party válido puede iniciar Quick Match.")
		return false
	if not Steamworks.initialized or _steam == null:
		queue_error.emit("Steam debe estar disponible para Quick Match.")
		return false
	if NetworkManager.lobby_id != 0:
		queue_error.emit("Ya estás conectado a una partida.")
		return false
	if not start_quick_match(PartyManager.size()):
		return false
	_steam_search_enabled = true
	_anchor_after_ms = ANCHOR_BASE_DELAY_MS + int(Steamworks.steam_id % ANCHOR_JITTER_MS)
	PartyManager.clear_match_target()
	_request_match_lobbies(true)
	return true

func start_quick_match(party_size: int) -> bool:
	if state != STATE_IDLE:
		return false
	if not QuickMatchRules.valid_party_size(party_size):
		queue_error.emit(
			"El grupo debe tener entre 1 y %d jugadores." % QuickMatchRules.TARGET_PLAYERS
		)
		return false
	local_party_size = party_size
	queue_started_ms = Time.get_ticks_msec()
	current_distance_tier = QuickMatchRules.DISTANCE_CLOSE
	_last_search_ms = 0
	_search_pending = false
	_candidate_lobby_id = 0
	_anchor_after_ms = ANCHOR_BASE_DELAY_MS
	_steam_search_enabled = false
	state = STATE_SEARCHING
	queue_state_changed.emit(state)
	search_scope_changed.emit(current_distance_tier)
	return true

func cancel_quick_match() -> void:
	if state == STATE_IDLE:
		return
	if state in [STATE_RESERVING, STATE_MATCH_FOUND] and NetworkManager.lobby_id != 0:
		NetworkManager.leave_lobby()
	if _steam_search_enabled and PartyManager.is_local_leader():
		PartyManager.clear_match_target()
	reset()
	queue_state_changed.emit(state)

func slots_needed() -> int:
	return QuickMatchRules.slots_needed(local_party_size)

func search_scope_name() -> String:
	match current_distance_tier:
		QuickMatchRules.DISTANCE_CLOSE:
			return "CLOSE"
		QuickMatchRules.DISTANCE_DEFAULT:
			return "DEFAULT"
		QuickMatchRules.DISTANCE_FAR:
			return "FAR"
		QuickMatchRules.DISTANCE_WORLDWIDE:
			return "WORLDWIDE"
		_:
			return "UNKNOWN"

func consider_candidates(candidates: Array[Dictionary]) -> Array[int]:
	if state != STATE_SEARCHING:
		return []
	var party_ids: Array[int] = QuickMatchRules.find_exact_fit(local_party_size, candidates)
	if party_ids.is_empty() and slots_needed() > 0:
		return []
	state = STATE_MATCH_FOUND
	queue_state_changed.emit(state)
	match_composition_found.emit(party_ids)
	return party_ids

func _request_match_lobbies(force: bool = false) -> void:
	if not _steam_search_enabled or state != STATE_SEARCHING or _steam == null or _search_pending:
		return
	var now_ms := Time.get_ticks_msec()
	if not force and now_ms - _last_search_ms < SEARCH_INTERVAL_MS:
		return
	_search_pending = true
	_last_search_ms = now_ms
	_steam.call(
		"addRequestLobbyListStringFilter",
		GAME_TAG_KEY,
		GAME_TAG_VALUE,
		STEAM_LOBBY_COMPARISON_EQUAL,
	)
	_steam.call(
		"addRequestLobbyListStringFilter",
		LOBBY_KIND_KEY,
		LOBBY_KIND_MATCH,
		STEAM_LOBBY_COMPARISON_EQUAL,
	)
	_steam.call(
		"addRequestLobbyListStringFilter",
		MATCH_STATE_KEY,
		MATCH_STATE_OPEN,
		STEAM_LOBBY_COMPARISON_EQUAL,
	)
	_steam.call("addRequestLobbyListDistanceFilter", current_distance_tier)
	_steam.call("addRequestLobbyListResultCountFilter", 50)
	_steam.call("requestLobbyList")

func _on_lobby_match_list(lobbies: Array) -> void:
	if not _search_pending or state != STATE_SEARCHING:
		return
	_search_pending = false
	var candidate := _choose_match_candidate(lobbies)
	if candidate.is_empty():
		return
	_candidate_lobby_id = int(candidate.get("lobby_id", 0))
	var open_slots := int(candidate.get("open_slots", 0))
	if _candidate_lobby_id <= 0:
		return
	state = STATE_RESERVING
	queue_state_changed.emit(state)
	match_candidate_found.emit(_candidate_lobby_id, open_slots)
	NetworkManager.join_lobby(_candidate_lobby_id)

func _choose_match_candidate(lobbies: Array) -> Dictionary:
	var best: Dictionary = {}
	for raw_lobby_id in lobbies:
		var candidate_id := int(raw_lobby_id)
		if candidate_id <= 0 or candidate_id == NetworkManager.lobby_id:
			continue
		var raw_open_slots := str(_steam.call("getLobbyData", candidate_id, OPEN_SLOTS_KEY))
		if not raw_open_slots.is_valid_int():
			continue
		var open_slots := int(raw_open_slots)
		if open_slots < local_party_size:
			continue
		if best.is_empty():
			best = {"lobby_id": candidate_id, "open_slots": open_slots}
			continue
		var best_open_slots := int(best.get("open_slots", QuickMatchRules.TARGET_PLAYERS + 1))
		if open_slots < best_open_slots:
			best = {"lobby_id": candidate_id, "open_slots": open_slots}
		elif open_slots == best_open_slots and candidate_id < int(best.get("lobby_id", candidate_id)):
			best = {"lobby_id": candidate_id, "open_slots": open_slots}
	return best

func _host_anchor_match() -> void:
	if state != STATE_SEARCHING or NetworkManager.lobby_id != 0:
		return
	state = STATE_HOSTING
	queue_state_changed.emit(state)
	NetworkManager.host_quick_match_lobby(PartyManager.member_ids())

func _on_party_reservation_result(accepted: bool) -> void:
	if state != STATE_RESERVING:
		return
	if not accepted:
		if NetworkManager.lobby_id != 0:
			NetworkManager.leave_lobby()
		_candidate_lobby_id = 0
		state = STATE_SEARCHING
		queue_state_changed.emit(state)
		_request_match_lobbies(true)
		return
	state = STATE_MATCH_FOUND
	queue_state_changed.emit(state)
	if PartyManager.is_local_leader():
		PartyManager.set_match_target(NetworkManager.lobby_id)

func _on_network_lobby_state_changed(network_state: StringName) -> void:
	if state == STATE_HOSTING and network_state == &"hosting":
		state = STATE_MATCH_FOUND
		queue_state_changed.emit(state)
		if PartyManager.is_local_leader():
			PartyManager.set_match_target(NetworkManager.lobby_id)
	elif state == STATE_RESERVING and network_state in [&"connection_failed", &"host_disconnected"]:
		_candidate_lobby_id = 0
		state = STATE_SEARCHING
		queue_state_changed.emit(state)

func _on_party_match_target_changed(target_lobby_id: int) -> void:
	if target_lobby_id <= 0:
		return
	if NetworkManager.lobby_id == target_lobby_id:
		return
	if NetworkManager.lobby_id != 0:
		return
	state = STATE_MATCH_FOUND
	queue_state_changed.emit(state)
	NetworkManager.join_lobby(target_lobby_id)

func _on_steam_unavailable(reason: String) -> void:
	_steam = null
	if state != STATE_IDLE and _steam_search_enabled:
		queue_error.emit(reason)
	reset()

func reset() -> void:
	state = STATE_IDLE
	local_party_size = 1
	queue_started_ms = 0
	current_distance_tier = QuickMatchRules.DISTANCE_CLOSE
	_search_pending = false
	_last_search_ms = 0
	_anchor_after_ms = ANCHOR_BASE_DELAY_MS
	_candidate_lobby_id = 0
	_steam_search_enabled = false
