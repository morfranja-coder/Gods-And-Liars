class_name GateCRematchLoopTest
extends GdUnitTestSuite

const TABLE_SCENE := preload("res://scenes/table/table.tscn")
const EXPECTED_PLAYERS := 8

func before_test() -> void:
	NetworkManager.reset()
	MatchAuthority.reset()
	GameManager.reset_match()
	_seed_roster()

func after_test() -> void:
	NetworkManager.reset()
	MatchAuthority.reset()
	GameManager.reset_match()

func test_rematch_resets_runtime_and_second_match_completes() -> void:
	var table := TABLE_SCENE.instantiate()
	add_child(table)
	await get_tree().process_frame
	await get_tree().process_frame

	var original_seats: Dictionary = {}
	for peer_id in range(1, EXPECTED_PLAYERS + 1):
		original_seats[peer_id] = int(NetworkManager.peers[peer_id].get("seat_id", -1))

	var first_result := QALocalMatchController.run(5151)
	await get_tree().process_frame
	assert_bool(bool(first_result.get("completed", false))).is_true()
	assert_int(int(GameManager.phase)).is_equal(int(GameManager.MatchPhase.MATCH_END))

	var match_end_panel := table.get_node_or_null("MatchEndUI/Panel") as Control
	assert_object(match_end_panel).is_not_null()
	assert_bool(match_end_panel.visible).is_true()

	MatchAuthority._sync_rematch()
	await get_tree().process_frame
	assert_int(int(GameManager.phase)).is_equal(int(GameManager.MatchPhase.READY))
	assert_str(str(MatchAuthority.public_winner)).is_empty()
	assert_int(int(MatchAuthority.local_role)).is_equal(int(PlayerState.Role.UNASSIGNED))
	assert_bool(match_end_panel.visible).is_false()

	for peer_id in range(1, EXPECTED_PLAYERS + 1):
		assert_bool(MatchAuthority.is_peer_publicly_alive(peer_id)).is_true()
		assert_int(int(NetworkManager.peers[peer_id].get("seat_id", -1))).is_equal(
			int(original_seats[peer_id])
		)

	var second_result := QALocalMatchController.run(6262)
	await get_tree().process_frame
	assert_bool(bool(second_result.get("completed", false))).is_true()
	assert_int(int(second_result.get("players", 0))).is_equal(EXPECTED_PLAYERS)
	assert_str(str(second_result.get("winner", ""))).is_not_empty()
	assert_int(int(GameManager.phase)).is_equal(int(GameManager.MatchPhase.MATCH_END))
	assert_str(str(MatchAuthority.public_winner)).is_equal(str(second_result.get("winner", "")))
	assert_bool(match_end_panel.visible).is_true()

	for peer_id in range(1, EXPECTED_PLAYERS + 1):
		assert_int(int(NetworkManager.peers[peer_id].get("seat_id", -1))).is_equal(
			int(original_seats[peer_id])
		)

	table.queue_free()
	await get_tree().process_frame

func _seed_roster() -> void:
	for peer_id in range(1, EXPECTED_PLAYERS + 1):
		NetworkManager.register_peer(
			peer_id,
			990000 + peer_id,
			"Gate C Rematch Bot %d" % peer_id,
			peer_id - 1,
		)
