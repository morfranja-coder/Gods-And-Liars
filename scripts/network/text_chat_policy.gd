class_name TextChatPolicy
extends RefCounted

const OPEN_PHASES := [
	GameManager.MatchPhase.BOOT,
	GameManager.MatchPhase.LOBBY,
	GameManager.MatchPhase.READY,
	GameManager.MatchPhase.DAY_DISCUSSION,
	GameManager.MatchPhase.VOTING,
	GameManager.MatchPhase.SACRIFICE,
	GameManager.MatchPhase.WIN_CHECK,
	GameManager.MatchPhase.MATCH_END,
]

static func can_general_chat(phase: int, sender_alive: bool) -> bool:
	return sender_alive and phase in OPEN_PHASES

static func can_private_chat(
	phase: int,
	sender_alive: bool,
	target_alive: bool,
	sender_role: PlayerState.Role,
	target_role: PlayerState.Role,
) -> bool:
	if not sender_alive or not target_alive:
		return false
	if phase in OPEN_PHASES:
		return true
	if phase != GameManager.MatchPhase.HERETIC_ACTION:
		return false
	return (
		sender_role == PlayerState.Role.HERETIC
		and target_role == PlayerState.Role.HERETIC
	)
