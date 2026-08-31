class_name PlayerListUI
extends CanvasLayer

signal open_state_changed(is_open: bool)

const TALKING_FLASH_SECONDS := 0.35
const DEAD_COLOR := Color(0.46, 0.46, 0.48, 0.72)
const ALIVE_COLOR := Color(0.92, 0.9, 0.82, 1.0)
const TALKING_COLOR := Color(0.82, 0.68, 0.38, 1.0)

var is_open: bool = false
var _talking_until: Dictionary = {}
var _row_by_peer: Dictionary = {}

@onready var panel: PanelContainer = %Panel
@onready var players_box: VBoxContainer = %PlayersBox
@onready var empty_label: Label = %EmptyLabel

func _ready() -> void:
	NetworkManager.peer_joined.connect(_on_roster_changed)
	NetworkManager.peer_left.connect(_on_roster_changed)
	NetworkManager.peer_updated.connect(_on_roster_changed)
	MatchAuthority.night_resolution_received.connect(_on_night_resolution)
	MatchAuthority.vote_resolution_received.connect(_on_vote_resolution)
	VoiceChat.remote_talking.connect(_on_remote_talking)
	VoiceChat.local_talking_changed.connect(_on_local_talking_changed)
	AudioSettings.peer_mute_changed.connect(_on_peer_mute_changed)
	_set_open(false)

func _process(_delta: float) -> void:
	if not is_open:
		return
	_refresh_talking_indicators()

func toggle() -> void:
	_set_open(not is_open)

func open() -> void:
	_set_open(true)

func close() -> void:
	_set_open(false)

func refresh() -> void:
	_clear_rows()
	var peers: Array = NetworkManager.peers.keys()
	peers.sort_custom(_sort_peer_ids_by_seat)
	var local_id := _local_peer_id()
	for raw_peer_id in peers:
		var peer_id := int(raw_peer_id)
		var peer: Dictionary = NetworkManager.peers.get(raw_peer_id, {})
		_add_player_row(peer_id, peer, local_id)
	empty_label.visible = peers.is_empty()

func _set_open(value: bool) -> void:
	if is_open == value and panel.visible == value:
		return
	is_open = value
	panel.visible = value
	if is_open:
		refresh()
	open_state_changed.emit(is_open)

func _add_player_row(peer_id: int, peer: Dictionary, local_id: int) -> void:
	var row := HBoxContainer.new()
	row.name = "Peer_%s" % peer_id
	row.custom_minimum_size = Vector2(0, 38)
	row.add_theme_constant_override("separation", 10)
	players_box.add_child(row)
	_row_by_peer[peer_id] = row

	var status := Label.new()
	status.name = "Status"
	status.custom_minimum_size = Vector2(22, 0)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(status)

	var name_label := Label.new()
	name_label.name = "PlayerName"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text = _display_name(peer_id, peer)
	row.add_child(name_label)

	var voice_label := Label.new()
	voice_label.name = "VoiceState"
	voice_label.custom_minimum_size = Vector2(82, 0)
	voice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(voice_label)

	var mute_button := Button.new()
	mute_button.name = "MuteButton"
	mute_button.custom_minimum_size = Vector2(118, 32)
	mute_button.disabled = peer_id == local_id
	mute_button.pressed.connect(_on_mute_pressed.bind(peer_id))
	row.add_child(mute_button)
	_update_row(peer_id)

func _update_row(peer_id: int) -> void:
	var row := _row_by_peer.get(peer_id) as HBoxContainer
	if row == null:
		return
	var alive := MatchAuthority.is_peer_publicly_alive(peer_id)
	var status := row.get_node("Status") as Label
	var name_label := row.get_node("PlayerName") as Label
	var voice_label := row.get_node("VoiceState") as Label
	var mute_button := row.get_node("MuteButton") as Button
	status.text = "●" if alive else "†"
	name_label.modulate = ALIVE_COLOR if alive else DEAD_COLOR
	status.modulate = ALIVE_COLOR if alive else DEAD_COLOR
	mute_button.text = "Vos" if mute_button.disabled else (
		"Volver a escuchar" if AudioSettings.is_peer_muted(peer_id) else "Silenciar"
	)
	_update_voice_indicator(peer_id, voice_label, alive)

func _update_voice_indicator(peer_id: int, voice_label: Label, alive: bool) -> void:
	if AudioSettings.is_peer_muted(peer_id):
		voice_label.text = "SILENCIADO"
		voice_label.modulate = DEAD_COLOR
		return
	var talking := _is_peer_talking(peer_id)
	voice_label.text = "HABLANDO" if talking else ""
	voice_label.modulate = TALKING_COLOR if talking else (ALIVE_COLOR if alive else DEAD_COLOR)

func _refresh_talking_indicators() -> void:
	for raw_peer_id in _row_by_peer.keys():
		var peer_id := int(raw_peer_id)
		var row := _row_by_peer[raw_peer_id] as HBoxContainer
		if row == null:
			continue
		var voice_label := row.get_node("VoiceState") as Label
		_update_voice_indicator(peer_id, voice_label, MatchAuthority.is_peer_publicly_alive(peer_id))

func _is_peer_talking(peer_id: int) -> bool:
	if peer_id == _local_peer_id():
		return VoiceChat.is_talking
	return Time.get_ticks_msec() <= int(_talking_until.get(peer_id, 0))

func _on_remote_talking(peer_id: int) -> void:
	_talking_until[peer_id] = Time.get_ticks_msec() + int(TALKING_FLASH_SECONDS * 1000.0)

func _on_local_talking_changed(_is_talking: bool) -> void:
	if is_open:
		_refresh_talking_indicators()

func _on_mute_pressed(peer_id: int) -> void:
	AudioSettings.toggle_peer_muted(peer_id)
	_update_row(peer_id)

func _on_peer_mute_changed(peer_id: int, _muted: bool) -> void:
	if is_open:
		_update_row(peer_id)

func _on_roster_changed(_peer_id: int) -> void:
	if is_open:
		refresh()

func _on_night_resolution(_killed_peer_ids: Array[int]) -> void:
	if is_open:
		refresh()

func _on_vote_resolution(_sacrificed_peer_id: int, _tied: bool) -> void:
	if is_open:
		refresh()

func _clear_rows() -> void:
	_row_by_peer.clear()
	for child in players_box.get_children():
		child.queue_free()

func _display_name(peer_id: int, peer: Dictionary) -> String:
	var display_name := str(peer.get("display_name", ""))
	if display_name.is_empty():
		display_name = "Player %s" % peer_id
	return display_name

func _local_peer_id() -> int:
	if multiplayer.multiplayer_peer == null:
		return 1
	return multiplayer.get_unique_id()

func _sort_peer_ids_by_seat(a: Variant, b: Variant) -> bool:
	var peer_a: Dictionary = NetworkManager.peers.get(a, {})
	var peer_b: Dictionary = NetworkManager.peers.get(b, {})
	return int(peer_a.get("seat_id", 99)) < int(peer_b.get("seat_id", 99))
