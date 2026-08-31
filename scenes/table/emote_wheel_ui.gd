class_name EmoteWheelUI
extends CanvasLayer

signal emote_requested(index: int)
signal open_state_changed(is_open: bool)

const SLOT_COUNT := 8
const STICK_THRESHOLD := 0.45

var is_open: bool = false
var selected_index: int = -1
var _controller_hold_mode: bool = false
var _buttons: Array[Button] = []

@onready var panel: PanelContainer = %Panel
@onready var slots_grid: GridContainer = %SlotsGrid
@onready var hint_label: Label = %HintLabel

func _ready() -> void:
	_collect_buttons()
	_set_open(false)

func _process(_delta: float) -> void:
	if not is_open or not _controller_hold_mode:
		return
	_update_controller_selection()

func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed(InputBindings.ACTION_EMOTE_MENU):
		if event is InputEventJoypadButton:
			_controller_hold_mode = true
			_set_open(true)
		else:
			_controller_hold_mode = false
			_set_open(not is_open)
		return true
	if event.is_action_released(InputBindings.ACTION_EMOTE_MENU):
		if _controller_hold_mode and is_open:
			if selected_index >= 0:
				_request_emote(selected_index)
			else:
				_set_open(false)
			_controller_hold_mode = false
			return true
	if not is_open:
		return false
	if event.is_action_pressed(InputBindings.ACTION_CANCEL):
		_controller_hold_mode = false
		_set_open(false)
		return true
	for index in range(SLOT_COUNT):
		if event.is_action_pressed(InputBindings.emote_action(index)):
			_request_emote(index)
			return true
	return false

func close() -> void:
	_controller_hold_mode = false
	_set_open(false)

func _collect_buttons() -> void:
	_buttons.clear()
	for child in slots_grid.get_children():
		if child is not Button:
			continue
		var button := child as Button
		var index := _buttons.size()
		button.pressed.connect(_on_slot_pressed.bind(index))
		_buttons.append(button)

func _set_open(value: bool) -> void:
	if is_open == value and panel.visible == value:
		return
	is_open = value
	panel.visible = value
	if is_open and not _controller_hold_mode and not _buttons.is_empty():
		_buttons[0].grab_focus()
	if not is_open:
		selected_index = -1
		_update_button_focus()
	open_state_changed.emit(is_open)

func _update_controller_selection() -> void:
	var horizontal := Input.get_axis(InputBindings.ACTION_LOOK_LEFT, InputBindings.ACTION_LOOK_RIGHT)
	var vertical := Input.get_axis(InputBindings.ACTION_LOOK_UP, InputBindings.ACTION_LOOK_DOWN)
	var direction := Vector2(horizontal, vertical)
	if direction.length() < STICK_THRESHOLD:
		_set_selected_index(-1)
		return
	var angle := fposmod(atan2(direction.x, -direction.y), TAU)
	var sector := int(round(angle / (TAU / float(SLOT_COUNT)))) % SLOT_COUNT
	_set_selected_index(sector)

func _set_selected_index(index: int) -> void:
	if selected_index == index:
		return
	selected_index = index
	_update_button_focus()

func _update_button_focus() -> void:
	for index in range(_buttons.size()):
		var button := _buttons[index]
		button.button_pressed = index == selected_index
		if index == selected_index:
			button.grab_focus()

func _request_emote(index: int) -> void:
	if index < 0 or index >= SLOT_COUNT:
		return
	emote_requested.emit(index)
	_set_open(false)

func _on_slot_pressed(index: int) -> void:
	_request_emote(index)
