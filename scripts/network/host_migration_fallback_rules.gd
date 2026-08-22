class_name HostMigrationFallbackRules
extends RefCounted

const DEFAULT_REASON := "No se pudo completar la transferencia de host."

static func should_start(fallback_active: bool) -> bool:
	return not fallback_active

static func normalize_reason(reason: String) -> String:
	var clean := reason.strip_edges()
	return clean if not clean.is_empty() else DEFAULT_REASON
