extends Node

const ACTION_CHAT := &"chat_open"
const ACTION_VOICE := &"voice_talk"
const ACTION_EMOTE_MENU := &"emote_menu"
const ACTION_PLAYER_LIST := &"player_list"
const ACTION_PAUSE := &"pause_menu"
const ACTION_SELECT := &"game_select"
const ACTION_CANCEL := &"game_cancel"
const ACTION_LOOK_LEFT := &"camera_look_left"
const ACTION_LOOK_RIGHT := &"camera_look_right"
const ACTION_LOOK_UP := &"camera_look_up"
const ACTION_LOOK_DOWN := &"camera_look_down"
const ACTION_UI_UP := &"menu_up"
const ACTION_UI_DOWN := &"menu_down"
const ACTION_UI_LEFT := &"menu_left"
const ACTION_UI_RIGHT := &"menu_right"
const ACTION_UI_CONFIRM := &"menu_confirm"
const ACTION_UI_BACK := &"menu_back"
const EMOTE_ACTIONS := [
	&"emote_1",
	&"emote_2",
	&"emote_3",
	&"emote_4",
	&"emote_5",
	&"emote_6",
	&"emote_7",
	&"emote_8",
]
const TOP_ROW_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8]
const KEYPAD_KEYS := [KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4, KEY_KP_5, KEY_KP_6, KEY_KP_7, KEY_KP_8]

var text_entry_active: bool = false

func _ready() -> void:
	_ensure_defaults()

func emote_action(index: int) -> StringName:
	if index < 0 or index >= EMOTE_ACTIONS.size():
		return StringName()
	return EMOTE_ACTIONS[index]

func set_text_entry_active(value: bool) -> void:
	text_entry_active = value

func _ensure_defaults() -> void:
	_ensure_action(ACTION_CHAT)
	_add_key(ACTION_CHAT, KEY_T)
	_add_joy_button(ACTION_CHAT, JOY_BUTTON_X)

	_ensure_action(ACTION_VOICE)
	_add_key(ACTION_VOICE, KEY_V)
	_add_joy_button(ACTION_VOICE, JOY_BUTTON_LEFT_SHOULDER)

	_ensure_action(ACTION_EMOTE_MENU)
	_add_key(ACTION_EMOTE_MENU, KEY_Z)
	_add_joy_button(ACTION_EMOTE_MENU, JOY_BUTTON_RIGHT_SHOULDER)

	_ensure_action(ACTION_PLAYER_LIST)
	_add_key(ACTION_PLAYER_LIST, KEY_TAB)
	_add_joy_button(ACTION_PLAYER_LIST, JOY_BUTTON_BACK)
	_add_joy_button(ACTION_PLAYER_LIST, JOY_BUTTON_MISC1)

	_ensure_action(ACTION_PAUSE)
	_add_key(ACTION_PAUSE, KEY_ESCAPE)
	_add_joy_button(ACTION_PAUSE, JOY_BUTTON_START)

	_ensure_action(ACTION_SELECT)
	_add_mouse_button(ACTION_SELECT, MOUSE_BUTTON_LEFT)
	_add_joy_button(ACTION_SELECT, JOY_BUTTON_A)

	_ensure_action(ACTION_CANCEL)
	_add_mouse_button(ACTION_CANCEL, MOUSE_BUTTON_RIGHT)
	_add_joy_button(ACTION_CANCEL, JOY_BUTTON_B)

	_ensure_camera_actions()
	_ensure_ui_actions()
	_ensure_emote_actions()

func _ensure_camera_actions() -> void:
	_ensure_action(ACTION_LOOK_LEFT, 0.2)
	_add_joy_axis(ACTION_LOOK_LEFT, JOY_AXIS_RIGHT_X, -1.0)
	_ensure_action(ACTION_LOOK_RIGHT, 0.2)
	_add_joy_axis(ACTION_LOOK_RIGHT, JOY_AXIS_RIGHT_X, 1.0)
	_ensure_action(ACTION_LOOK_UP, 0.2)
	_add_joy_axis(ACTION_LOOK_UP, JOY_AXIS_RIGHT_Y, -1.0)
	_ensure_action(ACTION_LOOK_DOWN, 0.2)
	_add_joy_axis(ACTION_LOOK_DOWN, JOY_AXIS_RIGHT_Y, 1.0)

func _ensure_ui_actions() -> void:
	_ensure_action(ACTION_UI_UP, 0.2)
	_add_joy_button(ACTION_UI_UP, JOY_BUTTON_DPAD_UP)
	_add_joy_axis(ACTION_UI_UP, JOY_AXIS_LEFT_Y, -1.0)
	_ensure_action(ACTION_UI_DOWN, 0.2)
	_add_joy_button(ACTION_UI_DOWN, JOY_BUTTON_DPAD_DOWN)
	_add_joy_axis(ACTION_UI_DOWN, JOY_AXIS_LEFT_Y, 1.0)
	_ensure_action(ACTION_UI_LEFT, 0.2)
	_add_joy_button(ACTION_UI_LEFT, JOY_BUTTON_DPAD_LEFT)
	_add_joy_axis(ACTION_UI_LEFT, JOY_AXIS_LEFT_X, -1.0)
	_ensure_action(ACTION_UI_RIGHT, 0.2)
	_add_joy_button(ACTION_UI_RIGHT, JOY_BUTTON_DPAD_RIGHT)
	_add_joy_axis(ACTION_UI_RIGHT, JOY_AXIS_LEFT_X, 1.0)
	_ensure_action(ACTION_UI_CONFIRM)
	_add_key(ACTION_UI_CONFIRM, KEY_ENTER)
	_add_key(ACTION_UI_CONFIRM, KEY_SPACE)
	_add_joy_button(ACTION_UI_CONFIRM, JOY_BUTTON_A)
	_ensure_action(ACTION_UI_BACK)
	_add_key(ACTION_UI_BACK, KEY_ESCAPE)
	_add_joy_button(ACTION_UI_BACK, JOY_BUTTON_B)

func _ensure_emote_actions() -> void:
	for index in range(EMOTE_ACTIONS.size()):
		var action: StringName = EMOTE_ACTIONS[index]
		_ensure_action(action)
		_add_key(action, TOP_ROW_KEYS[index])
		_add_key(action, KEYPAD_KEYS[index])

func _ensure_action(action: StringName, deadzone: float = 0.5) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, deadzone)
	else:
		InputMap.action_set_deadzone(action, deadzone)

func _add_key(action: StringName, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	_add_event_if_missing(action, event)

func _add_mouse_button(action: StringName, button_index: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	_add_event_if_missing(action, event)

func _add_joy_button(action: StringName, button_index: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	_add_event_if_missing(action, event)

func _add_joy_axis(action: StringName, axis: JoyAxis, axis_value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = axis_value
	_add_event_if_missing(action, event)

func _add_event_if_missing(action: StringName, event: InputEvent) -> void:
	if InputMap.action_has_event(action, event):
		return
	InputMap.action_add_event(action, event)
