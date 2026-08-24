class_name GateCFullLocalMatchTest
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

func test_full_local_match_reaches_match_end_on_real_table_scene() -> void:
	var table := TABLE_SCENE.instantiate()
	add_child(table)
	await get_tree().process_frame
	await get_tree().process_frame

	var result := QALocalMatchController.run(4242)
	await get_tree().process_frame

	assert_bool(bool(result.get("completed", false))).is_true()
	assert_int(int(result.get("players", 0))).is_equal(EXPECTED_PLAYERS)
	assert_str(str(result.get("winner", ""))).is_not_empty()
	assert_int(int(GameManager.phase)).is_equal(int(GameManager.MatchPhase.MATCH_END))
	assert_str(str(MatchAuthority.public_winner)).is_equal(str(result.get("winner", "")))

	var visited: Array = result.get("visited_phases", [])
	for required_phase in [
		GameManager.MatchPhase.ROLE_REVEAL,
		GameManager.MatchPhase.NIGHT_START,
		GameManager.MatchPhase.HERETIC_ACTION,
		GameManager.MatchPhase.HEALER_ACTION,
		GameManager.MatchPhase.INQUISITOR_ACTION,
		GameManager.MatchPhase.NIGHT_RESOLUTION,
		GameManager.MatchPhase.WIN_CHECK,
		GameManager.MatchPhase.MATCH_END,
	]:
		assert_bool(int(required_phase) in visited).override_failure_message(
			"Full local match never visited phase %s" % required_phase
		).is_true()
	assert_bool(
		int(GameManager.MatchPhase.DAY_DISCUSSION) in visited
		or int(GameManager.MatchPhase.MATCH_END) in visited
	).is_true()

	var match_end_panel := table.get_node_or_null("MatchEndUI/Panel") as Control
	var title := table.get_node_or_null("MatchEndUI/Panel/VBox/TitleLabel") as Label
	assert_object(match_end_panel).is_not_null()
	assert_bool(match_end_panel.visible).is_true()
	assert_object(title).is_not_null()
	assert_bool(
		title.text in ["VICTORIA DE LOS FIELES", "VICTORIA DE LOS HEREJES"]
	).is_true()

	var dead_public := 0
	for peer_id in range(1, EXPECTED_PLAYERS + 1):
		if not MatchAuthority.is_peer_publicly_alive(peer_id):
			dead_public += 1
	assert_int(dead_public).is_equal(EXPECTED_PLAYERS - int(result.get("living", 0)))

	table.queue_free()
	await get_tree().process_frame

func _seed_roster() -> void:
	for peer_id in range(1, EXPECTED_PLAYERS + 1):
		NetworkManager.register_peer(
			peer_id,
			980000 + peer_id,
			"Gate C Bot %d" % peer_id,
			peer_id - 1,
		)
