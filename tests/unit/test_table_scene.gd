class_name TableSceneTest
extends GdUnitTestSuite

const TABLE_SCENE := preload("res://scenes/table/table.tscn")

func before_test() -> void:
	NetworkManager.reset()
	MatchAuthority.reset()

func after_test() -> void:
	NetworkManager.reset()
	MatchAuthority.reset()

func test_table_builds_ten_seat_markers() -> void:
	var table := TABLE_SCENE.instantiate()
	add_child(table)
	await get_tree().process_frame
	var seats := table.get_node_or_null("Seats")
	assert_object(seats).is_not_null()
	assert_int(seats.get_child_count()).is_equal(TableLayout.SEAT_COUNT)
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
