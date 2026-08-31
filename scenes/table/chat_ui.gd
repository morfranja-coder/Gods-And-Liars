class_name ChatUI
extends CanvasLayer

signal open_state_changed(is_open: bool)
signal message_submitted(text: String)

const MAX_MESSAGE_LENGTH := 220

var is_open: bool = false

@onready var panel: PanelContainer = %Panel
@onready var input_line: LineEdit = %InputLine
@onready var hint_label: Label = %HintLabel

func _ready() -> void:
	input_line.text_submitted.connect(_on_text_submitted)
	_set_open(false)

func handle_input(event: InputEvent) -> bool:
	if is_open:
		if event.is_action_pressed(InputBindings.ACTION_UI_BACK):
			close()
			return true
		return false
	if event.is_action_pressed(InputBindings.ACTION_CHAT):
		open_for_typing(event is InputEventJoypadButton)
		return true
	return false

func open_for_typing(from_controller: bool = false) -> void:
	_set_open(true)
	input_line.grab_focus()
	if from_controller:
		_show_virtual_keyboard_if_supported()

func close() -> void:
	input_line.text = ""
	_set_open(false)

func _set_open(value: bool) -> void:
	if is_open == value and panel.visible == value:
		return
	is_open = value
	panel.visible = value
	InputBindings.set_text_entry_active(is_open)
	if not is_open:
		input_line.release_focus()
		if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
			DisplayServer.virtual_keyboard_hide()
	open_state_changed.emit(is_open)

func _on_text_submitted(text: String) -> void:
	var message := text.strip_edges()
	if message.is_empty():
		close()
		return
	if message.length() > MAX_MESSAGE_LENGTH:
		message = message.left(MAX_MESSAGE_LENGTH)
	message_submitted.emit(message)
	input_line.text = ""
	_set_open(false)

func _show_virtual_keyboard_if_supported() -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		return
	DisplayServer.virtual_keyboard_show(
		input_line.text,
		Rect2(),
		DisplayServer.KEYBOARD_TYPE_DEFAULT,
		MAX_MESSAGE_LENGTH,
		input_line.caret_column,
		input_line.caret_column
	)
