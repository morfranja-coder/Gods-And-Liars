extends SceneTree

const TABLE_SCENE := preload("res://scenes/table/table.tscn")
const EXPECTED_PLAYERS := 8

var _failures: Array[String] = []

func _init() -> void:
	call_deferred("_run_gate")

func _run_gate() -> void:
	NetworkManager.reset()
	MatchAuthority.reset()
	GameManager.reset_match()
	_seed_roster()

	var table := TABLE_SCENE.instantiate()
	get_root().add_child(table)
	await process_frame
	await process_frame

	_verify_table_hydration(table)
	_verify_role_reveal_ui(table)
	_verify_night_ui(table)
	_verify_day_vote_ui(table)
	_verify_public_death_refresh(table)
	_verify_match_end_ui(table)

	table.queue_free()
	await process_frame
	NetworkManager.reset()
	MatchAuthority.reset()
	GameManager.reset_match()

	if _failures.is_empty():
		print("GREEN: Gate C table integration passed (8 local players + phase UI).")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("RED: Gate C table integration failed with %d issue(s)." % _failures.size())
	quit(1)

func _seed_roster() -> void:
	for peer_id in range(1, EXPECTED_PLAYERS + 1):
		NetworkManager.register_peer(
			peer_id,
			970000 + peer_id,
			"Gate C Bot %d" % peer_id,
			peer_id - 1,
		)
		MatchAuthority.public_alive_by_peer[peer_id] = true

func _verify_table_hydration(table: Node) -> void:
	var seats := table.get_node_or_null("Seats")
	if seats == null:
		_fail("table did not create Seats node")
	else:
		if seats.get_child_count() != EXPECTED_PLAYERS:
			_fail("expected %d seat markers, got %d" % [EXPECTED_PLAYERS, seats.get_child_count()])
	for peer_id in range(1, EXPECTED_PLAYERS + 1):
		var avatar := table.get_node_or_null("Peer_%d" % peer_id)
		if avatar == null:
			_fail("missing avatar for peer %d" % peer_id)
			continue
		var seat := table.get_node_or_null("Seats/Seat_%02d" % peer_id) as Marker3D
		if seat == null:
			_fail("missing seat marker for peer %d" % peer_id)
			continue
		if not avatar.global_position.is_equal_approx(seat.global_position):
			_fail("peer %d avatar is not at authoritative seat" % peer_id)

func _verify_role_reveal_ui(table: Node) -> void:
	MatchAuthority.local_role = PlayerState.Role.FAITHFUL
	GameManager.set_phase(GameManager.MatchPhase.ROLE_REVEAL)
	MatchAuthority.private_role_received.emit(int(PlayerState.Role.FAITHFUL))
	var panel := table.get_node_or_null("RoleReveal/Panel") as Control
	var label := table.get_node_or_null("RoleReveal/Panel/VBox/RoleLabel") as Label
	if panel == null or not panel.visible:
		_fail("role reveal panel did not become visible")
	if label == null or label.text != "Fiel":
		_fail("role reveal did not render local role")

func _verify_night_ui(table: Node) -> void:
	MatchAuthority.local_role = PlayerState.Role.HERETIC
	GameManager.set_phase(GameManager.MatchPhase.HERETIC_ACTION)
	MatchAuthority.phase_synced.emit(int(GameManager.phase))
	var panel := table.get_node_or_null("NightActionUI/Panel") as Control
	var phase_label := table.get_node_or_null("NightActionUI/Panel/VBox/PhaseLabel") as Label
	if panel == null or not panel.visible:
		_fail("night action panel is hidden during Heretic phase")
	if phase_label == null or "Herejes" not in phase_label.text:
		_fail("night action phase label is not synchronized")

func _verify_day_vote_ui(table: Node) -> void:
	GameManager.set_phase(GameManager.MatchPhase.DAY_DISCUSSION)
	MatchAuthority.phase_synced.emit(int(GameManager.phase))
	var panel := table.get_node_or_null("DayVoteUI/Panel") as Control
	var label := table.get_node_or_null("DayVoteUI/Panel/VBox/PhaseLabel") as Label
	if panel == null or not panel.visible:
		_fail("day discussion panel is hidden")
	if label == null or label.text != "Día — Discusión":
		_fail("day discussion label is incorrect")

	GameManager.set_phase(GameManager.MatchPhase.VOTING)
	MatchAuthority.phase_synced.emit(int(GameManager.phase))
	if panel == null or not panel.visible:
		_fail("vote panel is hidden during voting")
	if label == null or label.text != "Día — Votación":
		_fail("vote label is incorrect")

func _verify_public_death_refresh(table: Node) -> void:
	MatchAuthority.public_alive_by_peer[3] = false
	MatchAuthority.night_resolution_received.emit([3])
	var avatar := table.get_node_or_null("Peer_3")
	if avatar == null:
		_fail("peer 3 avatar disappeared after death")
		return
	var label := avatar.get_node_or_null("NameLabel") as Label3D
	if label == null or not label.text.begins_with("† "):
		_fail("dead peer avatar was not marked as dead")

func _verify_match_end_ui(table: Node) -> void:
	MatchAuthority.public_winner = &"faithful"
	GameManager.set_phase(GameManager.MatchPhase.MATCH_END)
	MatchAuthority.match_end_received.emit(&"faithful")
	var panel := table.get_node_or_null("MatchEndUI/Panel") as Control
	var title := table.get_node_or_null("MatchEndUI/Panel/VBox/TitleLabel") as Label
	if panel == null or not panel.visible:
		_fail("match end panel did not become visible")
	if title == null or title.text != "VICTORIA DE LOS FIELES":
		_fail("match end winner text is incorrect")

func _fail(message: String) -> void:
	if _failures.size() < 100:
		_failures.append(message)
