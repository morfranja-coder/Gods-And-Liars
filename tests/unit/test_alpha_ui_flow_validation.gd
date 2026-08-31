class_name AlphaUIFlowValidationTest
extends GdUnitTestSuite

const MAIN_MENU_SCENE := preload("res://scenes/main_menu/main_menu.tscn")
const LOBBY_SCENE := preload("res://scenes/lobby/lobby.tscn")
const SETTINGS_SCENE := preload("res://scenes/settings/settings_menu.tscn")
const TABLE_SCENE := preload("res://scenes/table/table.tscn")
const EXPECTED_PLAYERS := 8

func before_test() -> void:
	NetworkManager.reset()
	MatchAuthority.reset()
	GameManager.reset_match()
	InputBindings.set_text_entry_active(false)

func after_test() -> void:
	InputBindings.set_text_entry_active(false)
	NetworkManager.reset()
	MatchAuthority.reset()
	GameManager.reset_match()

func test_controller_navigation_actions_are_available_to_godot_ui() -> void:
	assert_bool(_has_joy_button(&"ui_accept", JOY_BUTTON_A)).is_true()
	assert_bool(_has_joy_button(&"ui_cancel", JOY_BUTTON_B)).is_true()
	assert_bool(_has_joy_button(&"ui_up", JOY_BUTTON_DPAD_UP)).is_true()
	assert_bool(_has_joy_button(&"ui_down", JOY_BUTTON_DPAD_DOWN)).is_true()
	assert_bool(_has_joy_button(&"ui_left", JOY_BUTTON_DPAD_LEFT)).is_true()
	assert_bool(_has_joy_button(&"ui_right", JOY_BUTTON_DPAD_RIGHT)).is_true()
	assert_bool(_has_joy_axis(&"ui_up", JOY_AXIS_LEFT_Y, -1.0)).is_true()
	assert_bool(_has_joy_axis(&"ui_right", JOY_AXIS_LEFT_X, 1.0)).is_true()
	assert_bool(InputMap.has_action(InputBindings.ACTION_GHOST_FORWARD)).is_true()
	assert_bool(InputMap.has_action(InputBindings.ACTION_GHOST_ASCEND)).is_true()
	assert_bool(InputMap.has_action(InputBindings.ACTION_GHOST_DESCEND)).is_true()

func test_primary_scenes_expose_a_focusable_entry_point() -> void:
	var main_menu := MAIN_MENU_SCENE.instantiate()
	add_child(main_menu)
	await get_tree().process_frame
	assert_bool((main_menu.get_node("%EnterButton") as Button).has_focus()).is_true()
	main_menu.queue_free()
	await get_tree().process_frame

	var lobby := LOBBY_SCENE.instantiate()
	add_child(lobby)
	await get_tree().process_frame
	assert_object(get_viewport().gui_get_focus_owner()).is_not_null()
	lobby.queue_free()
	await get_tree().process_frame

	var settings := SETTINGS_SCENE.instantiate()
	add_child(settings)
	await get_tree().process_frame
	assert_object(get_viewport().gui_get_focus_owner()).is_not_null()
	var settings_panel := settings.get_node_or_null("Center/Panel") as PanelContainer
	assert_object(settings_panel).is_not_null()
	assert_int(settings_panel.size_flags_horizontal).is_equal(Control.SIZE_EXPAND_FILL)
	assert_int(settings_panel.size_flags_vertical).is_equal(Control.SIZE_EXPAND_FILL)
	assert_object(settings.get_node_or_null("Center/Panel/Margin/Scroll") as ScrollContainer).is_not_null()
	assert_object(settings.get_node_or_null("%BackButton") as Button).is_not_null()
	settings.queue_free()
	await get_tree().process_frame

func test_table_social_overlays_block_and_restore_gameplay_look() -> void:
	_seed_roster()
	var table := TABLE_SCENE.instantiate()
	add_child(table)
	await get_tree().process_frame
	await get_tree().process_frame
	var camera := table.get_node("Camera3D") as TableCameraLook
	var chat := table.get_node("ChatUI") as ChatUI
	var player_list := table.get_node("PlayerListUI") as PlayerListUI

	assert_bool(camera.look_enabled).is_true()
	chat.open_for_typing()
	assert_bool(chat.is_open).is_true()
	assert_bool(InputBindings.text_entry_active).is_true()
	assert_bool(camera.look_enabled).is_false()
	chat.close()
	assert_bool(InputBindings.text_entry_active).is_false()
	assert_bool(camera.look_enabled).is_true()

	player_list.open()
	assert_bool(player_list.is_open).is_true()
	assert_bool(camera.look_enabled).is_false()
	player_list.close()
	assert_bool(camera.look_enabled).is_true()

	table.queue_free()
	await get_tree().process_frame

func test_table_ui_contract_keeps_all_b1_to_b7_overlays_mounted() -> void:
	_seed_roster()
	var table := TABLE_SCENE.instantiate()
	add_child(table)
	await get_tree().process_frame
	assert_object(table.get_node_or_null("Camera3D") as TableCameraLook).is_not_null()
	assert_object(table.get_node_or_null("RoleReveal")).is_not_null()
	assert_object(table.get_node_or_null("NightActionUI")).is_not_null()
	assert_object(table.get_node_or_null("DayVoteUI")).is_not_null()
	assert_object(table.get_node_or_null("MatchEndUI")).is_not_null()
	assert_object(table.get_node_or_null("PlayerListUI") as PlayerListUI).is_not_null()
	assert_object(table.get_node_or_null("EmoteWheelUI") as EmoteWheelUI).is_not_null()
	assert_object(table.get_node_or_null("ChatUI") as ChatUI).is_not_null()
	assert_object(table.get_node_or_null("PauseUI")).is_not_null()
	table.queue_free()
	await get_tree().process_frame

func _seed_roster() -> void:
	for peer_id in range(1, EXPECTED_PLAYERS + 1):
		NetworkManager.register_peer(
			peer_id,
			980000 + peer_id,
			"UI Flow Bot %d" % peer_id,
			peer_id - 1,
		)
		MatchAuthority.public_alive_by_peer[peer_id] = true

func _has_joy_button(action: StringName, button: JoyButton) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and event.button_index == button:
			return true
	return false

func _has_joy_axis(action: StringName, axis: JoyAxis, axis_value: float) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadMotion:
			var motion := event as InputEventJoypadMotion
			if motion.axis == axis and is_equal_approx(motion.axis_value, axis_value):
				return true
	return false
