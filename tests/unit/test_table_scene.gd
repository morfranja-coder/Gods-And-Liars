class_name TableSceneTest
extends GdUnitTestSuite

const TABLE_SCENE := preload("res://scenes/table/table.tscn")

func before_test() -> void:
	NetworkManager.reset()
	MatchAuthority.reset()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

func after_test() -> void:
	multiplayer.multiplayer_peer = null
	NetworkManager.reset()
	MatchAuthority.reset()

func test_table_builds_exactly_eight_seat_markers() -> void:
	var table := TABLE_SCENE.instantiate()
	add_child(table)
	await get_tree().process_frame
	var seats := table.get_node_or_null("Seats")
	assert_object(seats).is_not_null()
	assert_int(TableLayout.SEAT_COUNT).is_equal(QuickMatchRules.TARGET_PLAYERS)
	assert_int(seats.get_child_count()).is_equal(QuickMatchRules.TARGET_PLAYERS)
	table.queue_free()

func test_roster_spawns_avatar_at_authoritative_seat() -> void:
	NetworkManager.register_peer(1, 1001, "Host", 4)
	var table := TABLE_SCENE.instantiate()
	add_child(table)
	await get_tree().process_frame
	var avatar := table.get_node_or_null("Peer_1") as Node3D
	var seat := table.get_node_or_null("Seats/Seat_05") as Marker3D
	assert_object(avatar).is_not_null()
	assert_object(seat).is_not_null()
	assert_bool(avatar.global_position.is_equal_approx(seat.global_position)).is_true()
	assert_object(avatar.get_node_or_null("Body/PersonajeAlfa")).is_not_null()
	table.queue_free()

func test_table_mounts_current_scenario_and_swaps_god_after_local_death() -> void:
	NetworkManager.register_peer(1, 1001, "Host", 0)
	MatchAuthority.public_alive_by_peer[1] = true
	var table := TABLE_SCENE.instantiate()
	add_child(table)
	await get_tree().process_frame
	var living_god := table.get_node("GodState/LivingGod") as Node3D
	var dead_god := table.get_node("GodState/DeadGod") as Node3D
	assert_object(_find_scenario_root(table)).is_not_null()
	assert_bool(living_god.visible).is_true()
	assert_bool(dead_god.visible).is_false()

	MatchAuthority.public_alive_by_peer[1] = false
	table.call("_refresh_god_state")
	assert_bool(living_god.visible).is_false()
	assert_bool(dead_god.visible).is_true()
	table.queue_free()

func test_peer_update_does_not_duplicate_avatar() -> void:
	NetworkManager.register_peer(1, 1001, "Host", 0)
	var table := TABLE_SCENE.instantiate()
	add_child(table)
	await get_tree().process_frame
	NetworkManager.set_peer_ready(1, true)
	await get_tree().process_frame
	assert_int(table.find_children("Peer_1", "Node3D", true, false).size()).is_equal(1)
	table.queue_free()

func test_selection_query_targets_avatar_areas_only() -> void:
	var table := TABLE_SCENE.instantiate()
	add_child(table)
	await get_tree().process_frame
	var query: PhysicsRayQueryParameters3D = table.call(
		"_make_selection_query",
		Vector3.ZERO,
		Vector3.FORWARD,
	)
	assert_bool(query.collide_with_areas).is_true()
	assert_bool(query.collide_with_bodies).is_false()
	assert_int(query.collision_mask).is_equal(2)
	table.queue_free()

func test_table_mounts_private_role_overlay() -> void:
	var table := TABLE_SCENE.instantiate()
	add_child(table)
	await get_tree().process_frame
	assert_object(table.get_node_or_null("RoleReveal")).is_not_null()
	table.queue_free()

func test_table_mounts_night_action_ui() -> void:
	var table := TABLE_SCENE.instantiate()
	add_child(table)
	await get_tree().process_frame
	assert_object(table.get_node_or_null("NightActionUI")).is_not_null()
	table.queue_free()

func test_table_mounts_day_vote_ui() -> void:
	var table := TABLE_SCENE.instantiate()
	add_child(table)
	await get_tree().process_frame
	assert_object(table.get_node_or_null("DayVoteUI")).is_not_null()
	table.queue_free()

func test_table_mounts_match_end_ui() -> void:
	var table := TABLE_SCENE.instantiate()
	add_child(table)
	await get_tree().process_frame
	assert_object(table.get_node_or_null("MatchEndUI")).is_not_null()
	table.queue_free()

func _find_scenario_root(table: Node) -> Node:
	for child in table.get_children():
		if str(child.name).begins_with("EscenarioAlfa"):
			return child
	return null
