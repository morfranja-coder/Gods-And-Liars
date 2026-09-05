class_name ChatUI
extends CanvasLayer

signal open_state_changed(is_open: bool)
signal message_submitted(text: String)
signal private_message_submitted(target_peer_id: int, text: String)

const MAX_MESSAGE_LENGTH := 220
const GENERAL_CHANNEL_ID := 0

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
	_rebuild_recipients(GENERAL_CHANNEL_ID)
	_select_recipient_by_peer_id(GENERAL_CHANNEL_ID)
	_refresh_history()
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
	if target_peer_id == GENERAL_CHANNEL_ID:
		_send_general_message(message)
		message_submitted.emit(message)
	else:
		_append_history(target_peer_id, "Vos: %s" % message)
		private_message_submitted.emit(target_peer_id, message)
	input_line.text = ""
	_refresh_history()
	input_line.grab_focus()

func _send_general_message(text: String) -> void:
	if MatchAuthority.is_local_ghost() or multiplayer.multiplayer_peer == null:
		return
	var local_peer_id := multiplayer.get_unique_id()
	if not MatchAuthority.is_peer_publicly_alive(local_peer_id):
		return
	var clean_text := text.strip_edges().left(MAX_MESSAGE_LENGTH)
	if clean_text.is_empty():
		return
	if multiplayer.is_server():
		_server_route_general_chat(local_peer_id, clean_text)
	else:
		_request_general_chat.rpc_id(1, clean_text)

func _server_route_general_chat(sender_peer_id: int, text: String) -> void:
	if not multiplayer.is_server():
		return
	if not NetworkManager.peers.has(sender_peer_id):
		return
	if not MatchAuthority.is_peer_publicly_alive(sender_peer_id):
		return
	var clean_text := text.strip_edges().left(MAX_MESSAGE_LENGTH)
	if clean_text.is_empty():
		return
	var sender_data: Dictionary = NetworkManager.peers.get(sender_peer_id, {})
	var sender_name := str(sender_data.get("display_name", "Acólito %d" % sender_peer_id))
	for raw_peer_id in NetworkManager.peers.keys():
		var peer_id := int(raw_peer_id)
		if not MatchAuthority.is_peer_publicly_alive(peer_id):
			continue
		if peer_id == multiplayer.get_unique_id():
			_receive_general_chat(sender_peer_id, sender_name, clean_text)
		elif not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
			_receive_general_chat.rpc_id(peer_id, sender_peer_id, sender_name, clean_text)

func _on_private_chat_received(sender_peer_id: int, sender_name: String, text: String) -> void:
	if MatchAuthority.is_local_ghost():
		return
	_append_history(sender_peer_id, "%s: %s" % [sender_name, text])
	if _selected_peer_id() == sender_peer_id:
		_refresh_history()
	else:
		hint_label.text = "Mensaje privado nuevo de %s" % sender_name

func _on_recipient_selected(_index: int) -> void:
	_refresh_history()
	if is_open:
		input_line.grab_focus()

func _on_roster_changed(_peer_id: int) -> void:
	var previous_peer_id := _selected_peer_id()
	_rebuild_recipients(previous_peer_id)

func _rebuild_recipients(preferred_peer_id: int = GENERAL_CHANNEL_ID) -> void:
	var previous := preferred_peer_id
	recipient.clear()
	recipient.add_item("GENERAL")
	recipient.set_item_metadata(0, GENERAL_CHANNEL_ID)
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
	_select_recipient_by_peer_id(previous)
	_refresh_history()

func _select_recipient_by_peer_id(peer_id: int) -> void:
	for index in range(recipient.item_count):
		if int(recipient.get_item_metadata(index)) == peer_id:
			recipient.select(index)
			return
	recipient.select(0)

func _selected_peer_id() -> int:
	if not is_instance_valid(recipient) or recipient.item_count == 0 or recipient.selected < 0:
		return GENERAL_CHANNEL_ID
	return int(recipient.get_item_metadata(recipient.selected))

func _append_history(peer_id: int, line: String) -> void:
	var lines: Array = _history_by_peer.get(peer_id, [])
	lines.append(line)
	if lines.size() > 60:
		lines.pop_front()
	_history_by_peer[peer_id] = lines

func _refresh_history() -> void:
	var peer_id := _selected_peer_id()
	var lines: Array = _history_by_peer.get(peer_id, [])
	var packed := PackedStringArray()
	for raw_line in lines:
		packed.append(str(raw_line))
	history.text = "\n".join(packed)
	if peer_id == GENERAL_CHANNEL_ID:
		hint_label.text = "Chat general · Enter: enviar · Esc/B: cerrar · Elegí un jugador para chat privado"
	else:
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

@rpc("any_peer", "reliable")
func _request_general_chat(text: String) -> void:
	if not multiplayer.is_server():
		return
	_server_route_general_chat(multiplayer.get_remote_sender_id(), text)

@rpc("authority", "call_remote", "reliable")
func _receive_general_chat(sender_peer_id: int, sender_name: String, text: String) -> void:
	if MatchAuthority.is_local_ghost():
		return
	_append_history(GENERAL_CHANNEL_ID, "%s: %s" % [sender_name, text])
	if _selected_peer_id() == GENERAL_CHANNEL_ID:
		_refresh_history()
	else:
		hint_label.text = "Mensaje nuevo en chat general"
