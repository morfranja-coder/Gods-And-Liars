extends GdUnitTestSuite

const ROLE_SCENE := preload("res://scenes/table/role_reveal.tscn")
const VOTE_SCENE := preload("res://scenes/table/day_vote_ui.tscn")

func before_test() -> void:
	PracticeManager.start_seven_bot_match(PlayerState.Role.INQUISITOR)
	MatchAuthority.begin_role_reveal()
	await get_tree().process_frame

func after_test() -> void:
	PracticeManager.stop_practice()

func test_late_role_acknowledgement_preserves_debate_and_hides_overlay() -> void:
	var ui := ROLE_SCENE.instantiate()
	add_child(ui)
	await get_tree().process_frame
	assert_bool(ui.get_node("Panel").visible).is_true()
	MatchAuthority._sync_phase(GameManager.MatchPhase.DAY_DISCUSSION, 1)
	assert_bool(ui.get_node("Panel").visible).is_false()
	MatchAuthority._server_acknowledge_role(1)
	assert_int(GameManager.phase).is_equal(GameManager.MatchPhase.DAY_DISCUSSION)
	MatchAuthority._start_god_intro()
	assert_int(GameManager.phase).is_equal(GameManager.MatchPhase.DAY_DISCUSSION)
	ui.queue_free()
	await get_tree().process_frame

func test_first_practice_vote_varies_and_preserves_human() -> void:
	GameManager.round_number = 1
	var targets: Dictionary = {}
	for bot in PracticeManager.bot_peer_ids():
		var target: int = PracticeManager._pick_vote_target(bot)
		assert_bool(target != 1 and target != bot).is_true()
		assert_bool(MatchAuthority.is_peer_publicly_alive(target)).is_true()
		targets[target] = true
	assert_bool(targets.size() > 1).is_true()

func test_vote_cards_accept_click_and_header_stays_inside_viewport() -> void:
	var ui := VOTE_SCENE.instantiate()
	add_child(ui)
	MatchAuthority._sync_phase(GameManager.MatchPhase.DAY_DISCUSSION, 1)
	MatchAuthority.request_begin_voting()
	# Exercise the real refresh with all seven bot votes displayed.
	for bot in PracticeManager.bot_peer_ids():
		MatchAuthority.public_votes[bot] = 4 if bot != 4 else 5
	ui.call("_refresh")
	await get_tree().process_frame
	await get_tree().process_frame
	var buttons: Dictionary = ui.get("_target_buttons")
	assert_int(buttons.size()).is_equal(7)
	assert_int((buttons[2] as Button).mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	var rect: Rect2 = ui.get_node("Panel/VBox/PhaseLabel").get_global_rect()
	assert_bool(rect.position.y >= 0).is_true()
	var click := InputEventMouseButton.new()
	click.position = (buttons[2] as Button).get_global_rect().get_center()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	get_viewport().push_input(click, true)
	click = click.duplicate()
	click.pressed = false
	get_viewport().push_input(click, true)
	await get_tree().process_frame
	assert_int(int(MatchAuthority.public_votes.get(1, 0))).is_equal(2)
	ui.queue_free()
	await get_tree().process_frame

func test_alive_player_starts_without_ghost_hud() -> void:
	var table := load("res://scenes/table/table.tscn").instantiate() as Node
	add_child(table)
	await get_tree().process_frame
	assert_bool(table.get_node("GhostHUD").visible).is_false()
	table.queue_free()
	await get_tree().process_frame

func test_voice_cleanup_replaces_active_playback() -> void:
	var old_playback: Object = VoiceChat.get("_playback")
	VoiceChat.reset_for_match_leave()
	assert_object(VoiceChat.get("_playback")).is_not_null()
	assert_bool(VoiceChat.get("_playback") != old_playback).is_true()
