class_name VoiceRouter
extends RefCounted

static func can_transmit(phase: int, sender_alive: bool) -> bool:
	if phase in [GameManager.MatchPhase.BOOT, GameManager.MatchPhase.LOBBY, GameManager.MatchPhase.READY, GameManager.MatchPhase.MATCH_END]:
		return true
	if phase in [GameManager.MatchPhase.DAY_DISCUSSION, GameManager.MatchPhase.VOTING, GameManager.MatchPhase.SACRIFICE, GameManager.MatchPhase.WIN_CHECK]:
		return true
	return false

static func can_receive(phase: int, sender_alive: bool, receiver_alive: bool) -> bool:
	if not can_transmit(phase, sender_alive):
		return false
	if phase in [GameManager.MatchPhase.BOOT, GameManager.MatchPhase.LOBBY, GameManager.MatchPhase.READY, GameManager.MatchPhase.MATCH_END]:
		return true
	if sender_alive:
		return true
	return not receiver_alive
