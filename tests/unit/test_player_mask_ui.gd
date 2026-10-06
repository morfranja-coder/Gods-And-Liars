extends GdUnitTestSuite

const ROSTER_HUD := preload("res://scenes/table/player_roster_hud.gd")

func before_test() -> void:
	PracticeManager.start_seven_bot_match(PlayerState.Role.INQUISITOR)
	MatchAuthority.begin_role_reveal()
	await get_tree().process_frame

func after_test() -> void:
	PracticeManager.stop_practice()

func test_roster_shows_only_local_role_and_player_colored_masks() -> void:
	var hud := CanvasLayer.new()
	hud.set_script(ROSTER_HUD)
	add_child(hud)
	await get_tree().process_frame
	var rows: Dictionary = hud.get("_rows")
	assert_int(rows.size()).is_equal(8)
	assert_str(rows[1].role.text).is_equal("Inquisidor")
	for peer_id in range(2, 9):
		assert_str(rows[peer_id].role.text).is_empty()
		assert_bool(rows[peer_id].role.visible).is_false()
		assert_bool(rows[peer_id].mask.modulate.is_equal_approx(PlayerColors.for_seat(peer_id - 1))).is_true()
	hud.queue_free()
	await get_tree().process_frame

func test_selection_cards_share_mask_texture_without_3d_viewports() -> void:
	var first := PlayerPortraitCards.create_player_button(2)
	var second := PlayerPortraitCards.create_player_button(3)
	add_child(first)
	add_child(second)
	var first_mask := first.find_child("PlayerMask", true, false) as TextureRect
	var second_mask := second.find_child("PlayerMask", true, false) as TextureRect
	assert_bool(first_mask.texture == second_mask.texture).is_true()
	assert_bool(first_mask.modulate != second_mask.modulate).is_true()
	assert_int(first.find_children("*", "SubViewport", true, false).size()).is_equal(0)
	first.queue_free()
	second.queue_free()
	await get_tree().process_frame

func test_voice_events_light_only_speaking_player_and_clear_after_silence() -> void:
	var hud := CanvasLayer.new()
	hud.set_script(ROSTER_HUD)
	add_child(hud)
	await get_tree().process_frame
	var rows: Dictionary = hud.get("_rows")
	VoiceChat.remote_talking.emit(2)
	assert_bool(rows[2].speaker.visible).is_true()
	assert_bool(rows[3].speaker.visible).is_false()
	assert_bool(rows[2].panel.get_theme_stylebox("panel") == rows[2].talking_style).is_true()
	VoiceChat.local_talking_changed.emit(true)
	assert_bool(rows[1].speaker.visible).is_true()
	VoiceChat.local_talking_changed.emit(false)
	assert_bool(rows[1].speaker.visible).is_false()
	await get_tree().create_timer(0.45).timeout
	await get_tree().process_frame
	assert_bool(rows[2].speaker.visible).is_false()
	assert_bool(rows[2].panel.get_theme_stylebox("panel") == rows[2].idle_style).is_true()
	hud.queue_free()
	await get_tree().process_frame
