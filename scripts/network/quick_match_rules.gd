class_name QuickMatchRules
extends RefCounted

const TARGET_PLAYERS := 8
const MIN_PARTY_SIZE := 1
const MAX_PARTY_SIZE := TARGET_PLAYERS

const DISTANCE_CLOSE := 0
const DISTANCE_DEFAULT := 1
const DISTANCE_FAR := 2
const DISTANCE_WORLDWIDE := 3

const EXPAND_DEFAULT_MS := 10000
const EXPAND_FAR_MS := 20000
const EXPAND_WORLDWIDE_MS := 40000

static func valid_party_size(party_size: int) -> bool:
	return party_size >= MIN_PARTY_SIZE and party_size <= MAX_PARTY_SIZE

static func slots_needed(party_size: int) -> int:
	if not valid_party_size(party_size):
		return TARGET_PLAYERS
	return TARGET_PLAYERS - party_size

static func distance_tier_for_elapsed(elapsed_ms: int) -> int:
	if elapsed_ms < EXPAND_DEFAULT_MS:
		return DISTANCE_CLOSE
	if elapsed_ms < EXPAND_FAR_MS:
		return DISTANCE_DEFAULT
	if elapsed_ms < EXPAND_WORLDWIDE_MS:
		return DISTANCE_FAR
	return DISTANCE_WORLDWIDE

static func can_form_match(party_sizes: Array[int]) -> bool:
	var total := 0
	for party_size in party_sizes:
		if not valid_party_size(party_size):
			return false
		total += party_size
	return total == TARGET_PLAYERS

static func find_exact_fit(base_party_size: int, candidates: Array[Dictionary]) -> Array[int]:
	if not valid_party_size(base_party_size):
		return []
	var needed := slots_needed(base_party_size)
	if needed == 0:
		return []
	var normalized: Array[Dictionary] = []
	for candidate in candidates:
		var size := int(candidate.get("party_size", 0))
		if not valid_party_size(size) or size > needed:
			continue
		normalized.append({
			"id": int(candidate.get("id", 0)),
			"party_size": size,
			"wait_ms": int(candidate.get("wait_ms", 0)),
		})
	normalized.sort_custom(_candidate_precedes)
	var result: Array[int] = []
	if _search_exact_fit(normalized, 0, needed, result):
		return result
	return []

static func _candidate_precedes(a: Dictionary, b: Dictionary) -> bool:
	var a_wait := int(a.get("wait_ms", 0))
	var b_wait := int(b.get("wait_ms", 0))
	if a_wait != b_wait:
		return a_wait > b_wait
	return int(a.get("party_size", 0)) > int(b.get("party_size", 0))

static func _search_exact_fit(
	candidates: Array[Dictionary],
	index: int,
	remaining: int,
	selected: Array[int],
) -> bool:
	if remaining == 0:
		return true
	if index >= candidates.size() or remaining < 0:
		return false
	for i in range(index, candidates.size()):
		var candidate := candidates[i]
		var size := int(candidate.get("party_size", 0))
		if size > remaining:
			continue
		selected.append(int(candidate.get("id", 0)))
		if _search_exact_fit(candidates, i + 1, remaining - size, selected):
			return true
		selected.pop_back()
	return false
