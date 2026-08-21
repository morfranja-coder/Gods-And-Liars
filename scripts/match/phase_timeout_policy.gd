class_name PhaseTimeoutPolicy
extends RefCounted

const ROLE_REVEAL_MS := 15000
const NIGHT_ACTION_MS := 20000
const DAY_DISCUSSION_MS := 90000
const VOTING_MS := 30000

static func timeout_ms_for_phase(phase: GameManager.MatchPhase) -> int:
	match phase:
		GameManager.MatchPhase.ROLE_REVEAL:
			return ROLE_REVEAL_MS
		GameManager.MatchPhase.HERETIC_ACTION, \
		GameManager.MatchPhase.HEALER_ACTION, \
		GameManager.MatchPhase.INQUISITOR_ACTION:
			return NIGHT_ACTION_MS
		GameManager.MatchPhase.DAY_DISCUSSION:
			return DAY_DISCUSSION_MS
		GameManager.MatchPhase.VOTING:
			return VOTING_MS
		_:
			return 0

static func has_timeout(phase: GameManager.MatchPhase) -> bool:
	return timeout_ms_for_phase(phase) > 0

static func deadline_ms(phase: GameManager.MatchPhase, now_ms: int) -> int:
	var duration := timeout_ms_for_phase(phase)
	return now_ms + duration if duration > 0 else 0
