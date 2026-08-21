extends Node

signal queue_state_changed(state: StringName)
signal search_scope_changed(distance_tier: int)
signal match_composition_found(party_ids: Array[int])
signal queue_error(message: String)

const STATE_IDLE := &"idle"
const STATE_SEARCHING := &"searching"
const STATE_MATCH_FOUND := &"match_found"

var state: StringName = STATE_IDLE
var local_party_size: int = 1
var queue_started_ms: int = 0
var current_distance_tier: int = QuickMatchRules.DISTANCE_CLOSE

func _process(_delta: float) -> void:
	if state != STATE_SEARCHING:
		return
	var elapsed_ms := max(0, Time.get_ticks_msec() - queue_started_ms)
	var next_tier := QuickMatchRules.distance_tier_for_elapsed(elapsed_ms)
	if next_tier != current_distance_tier:
		current_distance_tier = next_tier
		search_scope_changed.emit(current_distance_tier)

func start_quick_match(party_size: int) -> bool:
	if state == STATE_SEARCHING:
		return false
	if not QuickMatchRules.valid_party_size(party_size):
		queue_error.emit("El grupo debe tener entre 1 y %d jugadores." % QuickMatchRules.TARGET_PLAYERS)
		return false
	local_party_size = party_size
	queue_started_ms = Time.get_ticks_msec()
	current_distance_tier = QuickMatchRules.DISTANCE_CLOSE
	state = STATE_SEARCHING
	queue_state_changed.emit(state)
	search_scope_changed.emit(current_distance_tier)
	return true

func cancel_quick_match() -> void:
	if state == STATE_IDLE:
		return
	state = STATE_IDLE
	queue_started_ms = 0
	current_distance_tier = QuickMatchRules.DISTANCE_CLOSE
	queue_state_changed.emit(state)

func slots_needed() -> int:
	return QuickMatchRules.slots_needed(local_party_size)

func consider_candidates(candidates: Array[Dictionary]) -> Array[int]:
	if state != STATE_SEARCHING:
		return []
	var party_ids := QuickMatchRules.find_exact_fit(local_party_size, candidates)
	if party_ids.is_empty() and slots_needed() > 0:
		return []
	state = STATE_MATCH_FOUND
	queue_state_changed.emit(state)
	match_composition_found.emit(party_ids)
	return party_ids

func reset() -> void:
	state = STATE_IDLE
	local_party_size = 1
	queue_started_ms = 0
	current_distance_tier = QuickMatchRules.DISTANCE_CLOSE
