class_name NightPhaseRules
extends RefCounted

static func role_for_phase(phase: GameManager.MatchPhase) -> PlayerState.Role:
	match phase:
		GameManager.MatchPhase.HERETIC_ACTION:
			return PlayerState.Role.HERETIC
		GameManager.MatchPhase.HEALER_ACTION:
			return PlayerState.Role.HEALER
		GameManager.MatchPhase.INQUISITOR_ACTION:
			return PlayerState.Role.INQUISITOR
		_:
			return PlayerState.Role.UNASSIGNED

static func next_action_phase(phase: GameManager.MatchPhase) -> GameManager.MatchPhase:
	match phase:
		GameManager.MatchPhase.NIGHT_START:
			return GameManager.MatchPhase.HERETIC_ACTION
		GameManager.MatchPhase.HERETIC_ACTION:
			return GameManager.MatchPhase.HEALER_ACTION
		GameManager.MatchPhase.HEALER_ACTION:
			return GameManager.MatchPhase.INQUISITOR_ACTION
		GameManager.MatchPhase.INQUISITOR_ACTION:
			return GameManager.MatchPhase.NIGHT_RESOLUTION
		_:
			return phase

static func is_action_phase(phase: GameManager.MatchPhase) -> bool:
	return role_for_phase(phase) != PlayerState.Role.UNASSIGNED
