extends Node

signal phase_changed(previous_phase: int, new_phase: int)
signal match_started
signal match_ended(winner: StringName)

enum MatchPhase {
	BOOT,
	LOBBY,
	READY,
	ROLE_REVEAL,
	GOD_INTRO,
	NIGHT_START,
	HERETIC_ACTION,
	HEALER_ACTION,
	INQUISITOR_ACTION,
	NIGHT_RESOLUTION,
	DAY_ANNOUNCEMENT,
	DAY_DISCUSSION,
	VOTING,
	SACRIFICE,
	WIN_CHECK,
	MATCH_END,
}

var phase: MatchPhase = MatchPhase.BOOT
var round_number: int = 0

func set_phase(next_phase: MatchPhase) -> void:
	if phase == next_phase:
		return
	var previous := phase
	phase = next_phase
	phase_changed.emit(previous, phase)

func reset_match() -> void:
	round_number = 0
	set_phase(MatchPhase.LOBBY)

func start_match() -> void:
	round_number = 1
	set_phase(MatchPhase.ROLE_REVEAL)
	match_started.emit()

func start_next_round() -> void:
	round_number += 1
	set_phase(MatchPhase.NIGHT_START)

func end_match(winner: StringName) -> void:
	set_phase(MatchPhase.MATCH_END)
	match_ended.emit(winner)
