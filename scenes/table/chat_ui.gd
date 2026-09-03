class_name ChatUI
extends CanvasLayer

signal open_state_changed(is_open: bool)
signal message_submitted(text: String)
signal private_message_submitted(target_peer_id: int, text: String)

const MAX_MESSAGE_LENGTH := 220

var is_open: bool = false
var _history_by_peer: Dictionary = {}
var _table: Node = null

@onready var panel: PanelContainer = %Panel
@onready var recipient: OptionButton = %Recipient
@onready var history: RichTextLabel = %History
@onready var input_line: LineEdit = %InputLine
@onready var hint_label: Label = %HintLabel

func _ready() -> void:
	_table = get_parent()
	input_line.text_submitted.connect(_on_text_submitted)
	recipient.item_selected.connect(_on_recipient_selected)
	NetworkManager.peer_joined.connect(_on_roster_changed)
	NetworkManager.peer_left.connect(_on_roster_changed)
	NetworkManager.peer_updated.connect(_on_roster_changed)
	if _table != null and _table.has_signal("private_chat_received"):
		_table.connect("private_chat_received", _on_private_chat_received)
	_rebuild_recipients()
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
	if MatchAuthority.is_local_ghost():
		return
	_rebuild_recipients()
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
		return
	if message.length() > MAX_MESSAGE_LENGTH:
		message = message.left(MAX_MESSAGE_LENGTH)
	var target_peer_id := _selected_peer_id()
	if target_peer_id <= 0:
		hint_label.text = "Elegí un destinatario vivo."
		return
	_append_history(target_peer_id, "Vos: %s" % message)
	private_message_submitted.emit(target_peer_id, message)
	message_submitted.emit(message)
	input_line.text = ""
	_refresh_history()
	input_line.grab_focus()

func _on_private_chat_received(sender_peer_id: int, sender_name: String, text: String) -> void:
	if MatchAuthority.is_local_ghost():
		return
	_append_history(sender_peer_id, "%s: %s" % [sender_name, text])
	if _selected_peer_id() == sender_peer_id:
		_refresh_history()
	else:
		hint_label.text = "Mensaje nuevo de %s" % sender_name

func _on_recipient_selected(_index: int) -> void:
	_refresh_history()
	if is_open:
		input_line.grab_focus()

func _on_roster_changed(_peer_id: int) -> void:
	var previous_peer_id := _selected_peer_id()
	_rebuild_recipients(previous_peer_id)

func _rebuild_recipients(preferred_peer_id: int = 0) -> void:
	var previous := preferred_peer_id if preferred_peer_id > 0 else _selected_peer_id()
	recipient.clear()
	var local_peer_id := multiplayer.get_unique_id() if multiplayer.multiplayer_peer != null else 0
	var peer_ids := NetworkManager.peers.keys()
	peer_ids.sort_custom(func(a, b):
		var seat_a := int((NetworkManager.peers[a] as Dictionary).get("seat_id", 99))
		var seat_b := int((NetworkManager.peers[b] as Dictionary).get("seat_id", 99))
		return seat_a < seat_b
	)
	for raw_peer_id in peer_ids:
		var peer_id := int(raw_peer_id)
		if peer_id == local_peer_id or not MatchAuthority.is_peer_publicly_alive(peer_id):
			continue
		var index := recipient.item_count
		recipient.add_item(_peer_name(peer_id))
		recipient.set_item_metadata(index, peer_id)
	if recipient.item_count == 0:
		hint_label.text = "No hay otros jugadores vivos disponibles."
		_refresh_history()
		return
	var desired := previous
	if desired <= 0 and MatchAuthority.local_role == PlayerState.Role.HERETIC:
		desired = MatchAuthority.local_heretic_teammate_peer_id
	_select_recipient_by_peer_id(desired)
	_refresh_history()

func _select_recipient_by_peer_id(peer_id: int) -> void:
	if peer_id <= 0:
		recipient.select(0)
		return
	for index in range(recipient.item_count):
		if int(recipient.get_item_metadata(index)) == peer_id:
			recipient.select(index)
			return
	recipient.select(0)

func _selected_peer_id() -> int:
	if not is_instance_valid(recipient) or recipient.item_count == 0 or recipient.selected < 0:
		return 0
	return int(recipient.get_item_metadata(recipient.selected))

func _append_history(peer_id: int, line: String) -> void:
	var lines: Array = _history_by_peer.get(peer_id, [])
	lines.append(line)
	if lines.size() > 60:
		lines.pop_front()
	_history_by_peer[peer_id] = lines

func _refresh_history() -> void:
	var peer_id := _selected_peer_id()
	if peer_id <= 0:
		history.text = ""
		return
	var lines: Array = _history_by_peer.get(peer_id, [])
	var packed := PackedStringArray()
	for raw_line in lines:
		packed.append(str(raw_line))
	history.text = "\n".join(packed)
	hint_label.text = "Chat privado con %s · Enter: enviar · Esc/B: cerrar" % _peer_name(peer_id)

func _peer_name(peer_id: int) -> String:
	var data: Dictionary = NetworkManager.peers.get(peer_id, {})
	var name := str(data.get("display_name", ""))
	return name if not name.is_empty() else "Acólito %d" % peer_id

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
