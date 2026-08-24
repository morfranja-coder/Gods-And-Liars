class_name GateCTableIntegrationTest
extends GdUnitTestSuite

const TABLE_SCENE := preload("res://scenes/table/table.tscn")
const EXPECTED_PLAYERS := 8

func before_test() -> void:
	NetworkManager.reset()
	MatchAuthority.reset()
	GameManager.reset_match()

func after_test() -> void:
	NetworkManager.reset()
	MatchAuthority.reset()
	GameManager.reset_match()

func test_exact_eight_table_and_phase_ui_integration() -> void:
	_seed_roster()
	var table := TABLE_SCENE.instantiate()
	add_child(table)
	await get_tree().process_frame
	await get_tree().process_frame

	_verify_table_hydration(table)
	_verify_role_reveal_ui(table)
	_verify_night_ui(table)
	_verify_day_vote_ui(table)
	_verify_public_death_refresh(table)
	_verify_match_end_ui(table)

	table.queue_free()
	await get_tree().process_frame

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
	assert_object(seats).is_not_null()
	assert_int(seats.get_child_count()).is_equal(EXPECTED_PLAYERS)
	for peer_id in range(1, EXPECTED_PLAYERS + 1):
		var avatar := table.get_node_or_null("Peer_%d" % peer_id) as Node3D
		var seat := table.get_node_or_null("Seats/Seat_%02d" % peer_id) as Marker3D
		assert_object(avatar).is_not_null()
		assert_object(seat).is_not_null()
		assert_bool(avatar.global_position.is_equal_approx(seat.global_position)).is_true()

func _verify_role_reveal_ui(table: Node) -> void:
	MatchAuthority.local_role = PlayerState.Role.FAITHFUL
	GameManager.set_phase(GameManager.MatchPhase.ROLE_REVEAL)
	MatchAuthority.private_role_received.emit(int(PlayerState.Role.FAITHFUL))
	var panel := table.get_node_or_null("RoleReveal/Panel") as Control
	var label := table.get_node_or_null("RoleReveal/Panel/VBox/RoleLabel") as Label
	assert_object(panel).is_not_null()
	assert_bool(panel.visible).is_true()
	assert_object(label).is_not_null()
	assert_str(label.text).is_equal("Fiel")

func _verify_night_ui(table: Node) -> void:
	MatchAuthority.local_role = PlayerState.Role.HERETIC
	GameManager.set_phase(GameManager.MatchPhase.HERETIC_ACTION)
	MatchAuthority.phase_synced.emit(int(GameManager.phase))
	var panel := table.get_node_or_null("NightActionUI/Panel") as Control
	var phase_label := table.get_node_or_null("NightActionUI/Panel/VBox/PhaseLabel") as Label
	assert_object(panel).is_not_null()
	assert_bool(panel.visible).is_true()
	assert_object(phase_label).is_not_null()
	assert_str(phase_label.text).contains("Herejes")

func _verify_day_vote_ui(table: Node) -> void:
	GameManager.set_phase(GameManager.MatchPhase.DAY_DISCUSSION)
	MatchAuthority.phase_synced.emit(int(GameManager.phase))
	var panel := table.get_node_or_null("DayVoteUI/Panel") as Control
	var label := table.get_node_or_null("DayVoteUI/Panel/VBox/PhaseLabel") as Label
	assert_object(panel).is_not_null()
	assert_bool(panel.visible).is_true()
	assert_object(label).is_not_null()
	assert_str(label.text).is_equal("Día — Discusión")

	GameManager.set_phase(GameManager.MatchPhase.VOTING)
	MatchAuthority.phase_synced.emit(int(GameManager.phase))
	assert_bool(panel.visible).is_true()
	assert_str(label.text).is_equal("Día — Votación")

func _verify_public_death_refresh(table: Node) -> void:
	MatchAuthority.public_alive_by_peer[3] = false
	MatchAuthority.night_resolution_received.emit([3])
	var avatar := table.get_node_or_null("Peer_3")
	assert_object(avatar).is_not_null()
	var label := avatar.get_node_or_null("NameLabel") as Label3D
	assert_object(label).is_not_null()
	assert_bool(label.text.begins_with("† ")).is_true()

func _verify_match_end_ui(table: Node) -> void:
	MatchAuthority.public_winner = &"faithful"
	GameManager.set_phase(GameManager.MatchPhase.MATCH_END)
	MatchAuthority.match_end_received.emit(&"faithful")
	var panel := table.get_node_or_null("MatchEndUI/Panel") as Control
	var title := table.get_node_or_null("MatchEndUI/Panel/VBox/TitleLabel") as Label
	assert_object(panel).is_not_null()
	assert_bool(panel.visible).is_true()
	assert_object(title).is_not_null()
	assert_str(title.text).is_equal("VICTORIA DE LOS FIELES")
