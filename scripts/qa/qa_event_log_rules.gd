class_name QAEventLogRules
extends RefCounted

const MAX_CLIENT_LABEL_LENGTH := 32

static func sanitize_client_label(raw_label: String) -> String:
	var result := ""
	for character in raw_label.strip_edges().to_lower():
		if character.is_valid_identifier() or character.is_valid_int():
			result += character
		elif character in ["-", "_"]:
			result += character
	return result.left(MAX_CLIENT_LABEL_LENGTH)

static func make_record(
	event_name: String,
	payload: Dictionary,
	context: Dictionary,
) -> Dictionary:
	var record := context.duplicate(true)
	record["event"] = event_name.strip_edges()
	record["payload"] = payload.duplicate(true)
	return record

static func is_valid_record(record: Dictionary) -> bool:
	if str(record.get("event", "")).is_empty():
		return false
	for required_key in [
		"monotonic_ms",
		"unix_time",
		"client",
		"steam_id",
		"peer_id",
		"party_id",
		"target_match_id",
		"match_id",
		"lobby_id",
		"is_host",
		"roster_count",
		"open_slots",
		"queue_state",
		"phase",
		"round",
		"payload",
	]:
		if not record.has(required_key):
			return false
	return record["payload"] is Dictionary
