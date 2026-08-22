class_name PartyReservationPolicy
extends RefCounted

const TIMEOUT_MS := 15000

static func deadline_from(start_ms: int) -> int:
	return start_ms + TIMEOUT_MS

static func is_expired(deadline_ms: int, now_ms: int) -> bool:
	return deadline_ms > 0 and now_ms >= deadline_ms

static func expired_tokens(deadlines: Dictionary, now_ms: int) -> Array[int]:
	var tokens: Array[int] = []
	for raw_token in deadlines.keys():
		var token := int(raw_token)
		if is_expired(int(deadlines[raw_token]), now_ms):
			tokens.append(token)
	tokens.sort()
	return tokens
