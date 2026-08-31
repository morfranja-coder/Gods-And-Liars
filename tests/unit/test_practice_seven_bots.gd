class_name PracticeSevenBotsTest
extends GdUnitTestSuite

const MAIN_MENU_SCENE := preload("res://scenes/main_menu/main_menu.tscn")
const EXPECTED_PLAYERS := 8
const EXPECTED_BOTS := 7

func before_test() -> void:
	PracticeManager.stop_practice()

func after_test() -> void:
	PracticeManager.stop_practice()

func test_practice_mode_seeds_one_human_and_seven_bots() -> void:
	PracticeManager.start_seven_bot_match()
	assert_bool(PracticeManager.active).is_true()
	assert_int(NetworkManager.peers.size()).is_equal(EXPECTED_PLAYERS)
	assert_int(PracticeManager.bot_peer_ids().size()).is_equal(EXPECTED_BOTS)
	assert_bool(NetworkManager.is_host).is_true()
	assert_bool(NetworkManager.lobby_started).is_true()
	for seat_id in range(EXPECTED_PLAYERS):
		assert_bool(_seat_is_filled(seat_id)).is_true()

func test_main_menu_exposes_practice_launch() -> void:
	var menu := MAIN_MENU_SCENE.instantiate()
	add_child(menu)
	await get_tree().process_frame
	var practice_button := menu.get_node_or_null("%PracticeButton") as Button
	assert_object(practice_button).is_not_null()
	assert_str(practice_button.text).contains("7 BOTS")
	menu.queue_free()
	await get_tree().process_frame

func _seat_is_filled(seat_id: int) -> bool:
	for peer in NetworkManager.peers.values():
		if int(peer.get("seat_id", -1)) == seat_id:
			return true
	return false
