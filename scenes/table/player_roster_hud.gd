extends CanvasLayer

const SPEAKER_ICON := preload("res://assets/ui/speaker.svg")
const TALKING_HOLD_MS := 350
var _talking_until: Dictionary = {}
var _local_talking := false
var _rows: Dictionary = {}
var _strip: HBoxContainer

func _ready() -> void:
	layer = 29
	_strip = HBoxContainer.new()
	_strip.name = "PlayerStrip"
	_strip.anchor_left = 0.5
	_strip.anchor_right = 0.5
	_strip.offset_left = -600
	_strip.offset_right = 600
	_strip.offset_top = 4
	_strip.offset_bottom = 100
	_strip.add_theme_constant_override("separation", 6)
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_strip)
	NetworkManager.peer_joined.connect(_on_roster_changed)
	NetworkManager.peer_left.connect(_on_roster_changed)
	NetworkManager.peer_updated.connect(_on_roster_changed)
	_local_talking = VoiceChat.is_talking
	VoiceChat.remote_talking.connect(_on_remote_talking)
	VoiceChat.local_talking_changed.connect(_on_local_talking_changed)
	_rebuild()

func _on_remote_talking(peer_id: int) -> void:
	_talking_until[peer_id] = Time.get_ticks_msec() + TALKING_HOLD_MS
	_refresh()

func _on_local_talking_changed(talking: bool) -> void:
	_local_talking = talking
	_refresh()

func _on_roster_changed(_peer_id: int) -> void:
	_rebuild()

func _rebuild() -> void:
	for child in _strip.get_children():
		_strip.remove_child(child)
		child.queue_free()
	_rows.clear()
	var ids := NetworkManager.peers.keys()
	ids.sort_custom(func(a, b): return int(NetworkManager.peers[a].get("seat_id", 99)) < int(NetworkManager.peers[b].get("seat_id", 99)))
	for raw_id in ids:
		var peer_id := int(raw_id)
		var panel := PanelContainer.new()
		panel.name = "Peer_%d" % peer_id
		panel.custom_minimum_size.x = 144
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var box := VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_theme_constant_override("separation", 0)
		panel.add_child(box)
		var mask := PlayerPortraitCards.create_mask(peer_id, Vector2(0, 48))
		box.add_child(mask)
		var name_label := Label.new()
		name_label.name = "PlayerName"
		name_label.custom_minimum_size.x = 100
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name_row := HBoxContainer.new()
		name_row.alignment = BoxContainer.ALIGNMENT_CENTER
		name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_row.add_theme_constant_override("separation", 4)
		box.add_child(name_row)
		name_row.add_child(name_label)
		var speaker := TextureRect.new()
		speaker.name = "SpeakingIcon"
		speaker.texture = SPEAKER_ICON
		speaker.custom_minimum_size = Vector2(16, 16)
		speaker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		speaker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		speaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		speaker.tooltip_text = "Hablando"
		speaker.visible = false
		name_row.add_child(speaker)
		var idle_style := StyleBoxFlat.new()
		idle_style.bg_color = Color(0.04, 0.04, 0.04, 0.8)
		idle_style.set_border_width_all(1)
		idle_style.border_color = Color(0.2, 0.2, 0.2, 0.7)
		var talking_style := idle_style.duplicate() as StyleBoxFlat
		var color := PlayerColors.for_seat(int(NetworkManager.peers[peer_id].get("seat_id", -1)))
		talking_style.bg_color = Color(0.04, 0.04, 0.04, 0.92).lerp(Color(color.r, color.g, color.b, 0.92), 0.08)
		talking_style.border_color = color.lightened(0.45)
		talking_style.set_border_width_all(2)
		talking_style.shadow_color = Color(color.r, color.g, color.b, 0.65)
		talking_style.shadow_size = 6
		panel.add_theme_stylebox_override("panel", idle_style)
		var role_label := Label.new()
		role_label.name = "LocalRole"
		role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		role_label.add_theme_font_size_override("font_size", 14)
		role_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(role_label)
		_strip.add_child(panel)
		_rows[peer_id] = {"name": name_label, "role": role_label, "mask": mask, "speaker": speaker, "panel": panel, "idle_style": idle_style, "talking_style": talking_style}
	_refresh()

func _process(_delta: float) -> void:
	_refresh()

func _refresh() -> void:
	var local_id := multiplayer.get_unique_id() if multiplayer.multiplayer_peer != null else 0
	for raw_id in _rows:
		var peer_id := int(raw_id)
		var row: Dictionary = _rows[peer_id]
		var data: Dictionary = NetworkManager.peers.get(peer_id, {})
		var alive := MatchAuthority.is_peer_publicly_alive(peer_id)
		row.name.text = str(data.get("display_name", "Acólito %d" % peer_id)) + (" · Muerto" if not alive else "")
		# Only private local state is used. Other players' roles are never queried.
		row.role.text = MatchAuthority.role_title() if peer_id == local_id and MatchAuthority.local_role != PlayerState.Role.UNASSIGNED else ""
		row.role.visible = not row.role.text.is_empty()
		row.mask.modulate = PlayerColors.for_seat(int(data.get("seat_id", -1)))
		row.mask.modulate.a = 1.0 if alive else 0.4
		row.name.add_theme_color_override("font_color", row.mask.modulate)

		var talking := _local_talking if peer_id == local_id else Time.get_ticks_msec() < int(_talking_until.get(peer_id, 0))
		row.speaker.visible = talking
		row.speaker.modulate = PlayerColors.for_seat(int(data.get("seat_id", -1))).lightened(0.45)
		row.panel.add_theme_stylebox_override("panel", row.talking_style if talking else row.idle_style)
