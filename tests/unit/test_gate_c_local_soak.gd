class_name GateCLocalSoakTest
extends GdUnitTestSuite

const TABLE_SCENE := preload("res://scenes/table/table.tscn")
const EXPECTED_PLAYERS := 8
const MATCH_COUNT := 25

func before_test() -> void:
	NetworkManager.reset()
	MatchAuthority.reset()
	GameManager.reset_match()
	_seed_roster()

func after_test() -> void:
	NetworkManager.reset()
	MatchAuthority.reset()
	GameManager.reset_match()

func test_twenty_five_consecutive_local_matches_preserve_runtime_integrity() -> void:
	var table := TABLE_SCENE.instantiate()
	add_child(table)
	await get_tree().process_frame
	await get_tree().process_frame

	var original_seats: Dictionary = {}
	for peer_id in range(1, EXPECTED_PLAYERS + 1):
		original_seats[peer_id] = int(NetworkManager.peers[peer_id].get("seat_id", -1))

	for match_index in range(MATCH_COUNT):
		var result := QALocalMatchController.run(7000 + match_index)
		await get_tree().process_frame

		assert_bool(bool(result.get("completed", false))).override_failure_message(
			"Local soak match %d did not complete" % (match_index + 1)
		).is_true()
		assert_int(int(result.get("players", 0))).is_equal(EXPECTED_PLAYERS)
		assert_str(str(result.get("winner", ""))).is_not_empty()
		assert_int(int(GameManager.phase)).is_equal(int(GameManager.MatchPhase.MATCH_END))
		assert_str(str(MatchAuthority.public_winner)).is_equal(str(result.get("winner", "")))

		var dead_public := 0
		for peer_id in range(1, EXPECTED_PLAYERS + 1):
			if not MatchAuthority.is_peer_publicly_alive(peer_id):
				dead_public += 1
			assert_int(int(NetworkManager.peers[peer_id].get("seat_id", -1))).is_equal(
				int(original_seats[peer_id])
			)
		assert_int(dead_public).is_equal(EXPECTED_PLAYERS - int(result.get("living", 0)))

		if match_index < MATCH_COUNT - 1:
			MatchAuthority._sync_rematch()
			await get_tree().process_frame
			assert_int(int(GameManager.phase)).is_equal(int(GameManager.MatchPhase.READY))
			assert_str(str(MatchAuthority.public_winner)).is_empty()
			assert_int(int(MatchAuthority.local_role)).is_equal(int(PlayerState.Role.UNASSIGNED))
			for peer_id in range(1, EXPECTED_PLAYERS + 1):
				assert_bool(MatchAuthority.is_peer_publicly_alive(peer_id)).is_true()

	var match_end_panel := table.get_node_or_null("MatchEndUI/Panel") as Control
	assert_object(match_end_panel).is_not_null()
	assert_bool(match_end_panel.visible).is_true()

	table.queue_free()
	await get_tree().process_frame

func _seed_roster() -> void:
	for peer_id in range(1, EXPECTED_PLAYERS + 1):
		NetworkManager.register_peer(
			peer_id,
			995000 + peer_id,
			"Gate C Soak Bot %d" % peer_id,
			peer_id - 1,
		)
