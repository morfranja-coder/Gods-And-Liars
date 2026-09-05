class_name GateCTableIntegrationTest
extends GdUnitTestSuite

const TABLE_SCENE := preload("res://scenes/table/table.tscn")
const EXPECTED_PLAYERS := 8
const NAME_COLOR_TARGET := Color(0.95, 0.92, 0.85, 1.0)
const NAME_COLOR_SOFTENING := 0.35

func before_test() -> void:
	NetworkManager.reset()
	MatchAuthority.reset()
	GameManager.reset_match()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

func after_test() -> void:
	multiplayer.multiplayer_peer = null
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
	await _verify_day_vote_ui(table)
	await _verify_public_death_refresh(table)
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
		var label := avatar.get_node_or_null("NameLabel") as Label3D
		assert_object(label).is_not_null()
		assert_str(label.text).is_equal("Gate C Bot %d" % peer_id)
		var seat_color := PlayerColors.for_seat(peer_id - 1)
		assert_bool((avatar as AvatarSlots).get_player_color().is_equal_approx(seat_color)).is_true()
		var expected_label_color := seat_color.lerp(NAME_COLOR_TARGET, NAME_COLOR_SOFTENING)
		assert_bool(label.modulate.is_equal_approx(expected_label_color)).is_true()

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
	MatchAuthority.current_heretic_decider_peer_id = multiplayer.get_unique_id()
	GameManager.round_number = 1
	GameManager.set_phase(GameManager.MatchPhase.HERETIC_ACTION)
	MatchAuthority.phase_synced.emit(int(GameManager.phase))
	var panel := table.get_node_or_null("NightActionUI/Panel") as Control
	var phase_label := table.get_node_or_null("NightActionUI/Panel/VBox/PhaseLabel") as Label
	assert_object(panel).is_not_null()
	assert_bool(panel.visible).is_true()
	assert_object(phase_label).is_not_null()
	assert_str(phase_label.text).contains("HEREJES")

func _verify_day_vote_ui(table: Node) -> void:
	GameManager.round_number = 1
	GameManager.set_phase(GameManager.MatchPhase.DAY_DISCUSSION)
	MatchAuthority.phase_synced.emit(int(GameManager.phase))
	await get_tree().process_frame
	var panel := table.get_node_or_null("DayVoteUI/Panel") as Control
	var discussion_timer := table.get_node_or_null("DayVoteUI/DiscussionTimer") as Label
	assert_object(panel).is_not_null()
	assert_bool(panel.visible).is_false()
	assert_object(discussion_timer).is_not_null()
	assert_bool(discussion_timer.visible).is_true()

	MatchAuthority.current_voter_peer_id = multiplayer.get_unique_id()
	GameManager.set_phase(GameManager.MatchPhase.VOTING)
	MatchAuthority.phase_synced.emit(int(GameManager.phase))
	await get_tree().process_frame
	var label := table.get_node_or_null("DayVoteUI/Panel/VBox/PhaseLabel") as Label
	var target_center := table.get_node_or_null("DayVoteUI/Panel/VBox/TargetCenter") as CenterContainer
	var target_grid := table.get_node_or_null("DayVoteUI/Panel/VBox/TargetCenter/TargetGrid") as GridContainer
	assert_bool(panel.visible).is_true()
	assert_object(label).is_not_null()
	assert_str(label.text).contains("DÍA")
	assert_object(target_center).is_not_null()
	assert_bool(target_center.visible).is_true()
	assert_object(target_grid).is_not_null()
	assert_bool(target_grid.get_child_count() >= EXPECTED_PLAYERS - 1).is_true()

func _verify_public_death_refresh(table: Node) -> void:
	MatchAuthority.public_alive_by_peer[3] = false
	var killed_peer_ids: Array[int] = [3]
	MatchAuthority.night_resolution_received.emit(killed_peer_ids)
	var avatar := table.get_node_or_null("Peer_3") as Node3D
	assert_object(avatar).is_not_null()
	var label := avatar.get_node_or_null("NameLabel") as Label3D
	assert_object(label).is_not_null()
	assert_bool(label.visible).is_false()
	await get_tree().process_frame
	assert_bool(avatar.visible).is_false()

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
