class_name RateLimitPolicy
extends RefCounted

const READY_MIN_INTERVAL_MS := 100

static func can_accept(last_ms: int, now_ms: int, min_interval_ms: int = READY_MIN_INTERVAL_MS) -> bool:
	if now_ms < 0 or last_ms < 0:
		return false
	if last_ms == 0:
		return true
	return now_ms - last_ms >= min_interval_ms
