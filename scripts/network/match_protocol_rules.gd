class_name MatchProtocolRules
extends RefCounted

const PROTOCOL_VERSION := 1
const PROTOCOL_VERSION_KEY := "protocol_version"
const BUILD_VERSION_KEY := "build_version"

static func protocol_value() -> String:
	return str(PROTOCOL_VERSION)

static func current_build_version() -> String:
	var environment_version := OS.get_environment("GODS_AND_LIARS_BUILD_VERSION").strip_edges()
	if not environment_version.is_empty():
		return environment_version
	var project_version := str(
		ProjectSettings.get_setting("application/config/version", "")
	).strip_edges()
	return project_version if not project_version.is_empty() else "dev"

static func compatible_protocol(raw_protocol: String) -> bool:
	return raw_protocol.strip_edges() == protocol_value()
