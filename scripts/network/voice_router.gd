class_name VoiceRouter
extends RefCounted

const ALWAYS_OPEN_PHASES := [
	GameManager.MatchPhase.BOOT,
	GameManager.MatchPhase.LOBBY,
	GameManager.MatchPhase.READY,
	GameManager.MatchPhase.MATCH_END,
]
const DAY_OPEN_PHASES := [
	GameManager.MatchPhase.DAY_DISCUSSION,
	GameManager.MatchPhase.VOTING,
	GameManager.MatchPhase.SACRIFICE,
	GameManager.MatchPhase.WIN_CHECK,
]

static func can_transmit(phase: int, _sender_alive: bool) -> bool:
	return phase in ALWAYS_OPEN_PHASES or phase in DAY_OPEN_PHASES

static func can_receive(phase: int, sender_alive: bool, receiver_alive: bool) -> bool:
	if not can_transmit(phase, sender_alive):
		return false
	if phase in ALWAYS_OPEN_PHASES:
		return true
	if sender_alive:
		return true
	return not receiver_alive
