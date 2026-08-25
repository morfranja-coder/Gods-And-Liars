extends "res://tests/acceptance/gate_d_full_match_end.gd"

func _validate_win_check(round_value: int) -> void:
	var session: MatchSession = MatchAuthority.get("_session")
	if session == null:
		_fail("server lost authoritative session before win check")
		return
	var winner := session.winner()
	var vote_resolved := _vote_resolution_rounds.has(round_value)
	if not vote_resolved and not winner.is_empty():
		_fail("winner appeared before round vote resolution")
	elif round_value == EXPECTED_FINAL_ROUND and vote_resolved and winner != &"faithful":
		_fail("second-round vote win check did not produce faithful winner")
