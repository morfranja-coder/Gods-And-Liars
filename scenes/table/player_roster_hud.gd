extends CanvasLayer

const SPEAKER_ICON := preload("res://assets/ui/speaker.svg")
const TALKING_HOLD_MS := 350
const HUD := preload("res://ui/ritual_hud_theme.gd")
var _phase_title: Label
var _phase_day: Label
var _phase_clock: Label
var _phase_progress: ProgressBar
var _role_badge: PanelContainer
var _role_title: Label
var _role_mask: TextureRect
var _talking_until: Dictionary = {}
var _local_talking := false
var _rows: Dictionary = {}
var _strip: HBoxContainer


func _ready() -> void:
	layer = 29
	_strip = HBoxContainer.new()
	_strip.name = "PlayerStrip"
	_strip.anchor_left = 0.025
	_strip.anchor_right = 0.975
	_strip.offset_left = 0
	_strip.offset_right = 0
	_strip.offset_top = 10
	_strip.offset_bottom = 86
	_strip.add_theme_constant_override("separation", 0)
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_strip)
	_build_role_badge()
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
	_phase_title = null
	for child in _strip.get_children():
		_strip.remove_child(child)
		child.queue_free()
	_rows.clear()
	var ids := NetworkManager.peers.keys()
	ids.sort_custom(func(a, b): return int(NetworkManager.peers[a].get("seat_id", 99)) < int(NetworkManager.peers[b].get("seat_id", 99)))
	for raw_id in ids:
		if _strip.get_child_count() == 4:
			_build_phase_cell()
		var peer_id := int(raw_id)
		var panel := PanelContainer.new()
		panel.name = "Peer_%d" % peer_id
		panel.custom_minimum_size.x = 0
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var box := VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_theme_constant_override("separation", 0)
		panel.add_child(box)
		var mask := PlayerPortraitCards.create_mask(peer_id, Vector2(0, 40))
		box.add_child(mask)
		var name_label := Label.new()
		name_label.name = "PlayerName"
		name_label.custom_minimum_size.x = 78
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.add_theme_font_override("font", HUD.strong_font())
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
		var idle_style := HUD.flat_style(Color(0.42, 0.32, 0.18, 0.65))
		idle_style.set_content_margin_all(5)
		var talking_style := idle_style.duplicate() as StyleBoxFlat
		var color := PlayerColors.for_seat(int(NetworkManager.peers[peer_id].get("seat_id", -1)))
		talking_style.bg_color = Color(0.12, 0.085, 0.035, 0.95)
		talking_style.border_color = color.lightened(0.45)
		talking_style.set_border_width_all(2)
		panel.add_theme_stylebox_override("panel", idle_style)
		var role_label := Label.new()
		role_label.name = "LocalRole"
		role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		role_label.add_theme_font_size_override("font_size", 14)
		role_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(role_label)
		role_label.visible = false
		_strip.add_child(panel)
		_rows[peer_id] = {"name": name_label, "role": role_label, "mask": mask, "speaker": speaker, "panel": panel, "idle_style": idle_style, "talking_style": talking_style}
	_refresh()


func _process(_delta: float) -> void:
	_refresh()
	_refresh_phase()


func _refresh() -> void:
	var local_id := multiplayer.get_unique_id() if multiplayer.multiplayer_peer != null else 0
	_role_badge.visible = local_id > 0 and MatchAuthority.local_role != PlayerState.Role.UNASSIGNED
	_role_title.text = MatchAuthority.role_title()
	_role_mask.modulate = PlayerColors.for_seat(int(NetworkManager.peers.get(local_id, {}).get("seat_id", -1)))
	for raw_id in _rows:
		var peer_id := int(raw_id)
		var row: Dictionary = _rows[peer_id]
		var data: Dictionary = NetworkManager.peers.get(peer_id, {})
		var alive := MatchAuthority.is_peer_publicly_alive(peer_id)
		row.name.text = str(data.get("display_name", "Acólito %d" % peer_id)) + (" · Muerto" if not alive else "")
		# Only private local state is used. Other players' roles are never queried.
		row.role.text = MatchAuthority.role_title() if peer_id == local_id and MatchAuthority.local_role != PlayerState.Role.UNASSIGNED else ""
		row.role.visible = false
		row.mask.modulate = PlayerColors.for_seat(int(data.get("seat_id", -1)))
		row.mask.modulate.a = 1.0 if alive else 0.4
		row.name.add_theme_color_override("font_color", row.mask.modulate)

		var talking := _local_talking if peer_id == local_id else Time.get_ticks_msec() < int(_talking_until.get(peer_id, 0))
		row.speaker.visible = talking
		row.speaker.modulate = PlayerColors.for_seat(int(data.get("seat_id", -1))).lightened(0.45)
		row.panel.add_theme_stylebox_override("panel", row.talking_style if talking else row.idle_style)


func _build_phase_cell() -> void:
	var cell := PanelContainer.new()
	cell.name = "RitualPhase"
	cell.custom_minimum_size.x = 196
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_theme_stylebox_override("panel", HUD.panel_style(12))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	cell.add_child(box)
	_phase_day = Label.new()
	_phase_day.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_day.add_theme_font_size_override("font_size", 10)
	_phase_day.add_theme_font_override("font", HUD.strong_font())
	_phase_day.add_theme_color_override("font_color", HUD.GOLD.lightened(0.25))
	box.add_child(_phase_day)
	_phase_title = Label.new()
	_phase_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_title.add_theme_font_override("font", HUD.heading_font())
	_phase_title.add_theme_font_size_override("font_size", 17)
	_phase_title.add_theme_color_override("font_color", HUD.IVORY)
	box.add_child(_phase_title)
	_phase_clock = Label.new()
	_phase_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_clock.add_theme_font_size_override("font_size", 15)
	_phase_clock.add_theme_font_override("font", HUD.strong_font())
	box.add_child(_phase_clock)
	_phase_progress = ProgressBar.new()
	_phase_progress.show_percentage = false
	_phase_progress.custom_minimum_size.y = 3
	var track := HUD.flat_style(Color.TRANSPARENT, Color(0.14, 0.10, 0.05))
	track.set_content_margin_all(0)
	track.set_border_width_all(0)
	_phase_progress.add_theme_stylebox_override("background", track)
	var fill := HUD.flat_style(Color.TRANSPARENT, HUD.GOLD)
	fill.set_content_margin_all(0)
	fill.set_border_width_all(0)
	_phase_progress.add_theme_stylebox_override("fill", fill)
	box.add_child(_phase_progress)
	_strip.add_child(cell)


func _build_role_badge() -> void:
	_role_badge = PanelContainer.new()
	_role_badge.name = "PrivateRoleBadge"
	_role_badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_role_badge.offset_left = -256
	_role_badge.offset_right = -22
	_role_badge.offset_top = -98
	_role_badge.offset_bottom = -18
	_role_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_role_badge.add_theme_stylebox_override("panel", HUD.panel_style(18))
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_role_badge.add_child(box)
	_role_mask = TextureRect.new()
	_role_mask.texture = PlayerPortraitCards.MASK_TEXTURE
	_role_mask.custom_minimum_size = Vector2(28, 40)
	_role_mask.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_role_mask.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(_role_mask)
	var text := VBoxContainer.new()
	box.add_child(text)
	_role_title = Label.new()
	_role_title.add_theme_font_override("font", HUD.heading_font())
	_role_title.add_theme_font_size_override("font_size", 18)
	_role_title.add_theme_color_override("font_color", HUD.IVORY)
	text.add_child(_role_title)
	var hint := Label.new()
	hint.text = "TU ROL · PRIVADO"
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_font_override("font", HUD.strong_font())
	hint.add_theme_color_override("font_color", HUD.GOLD.lightened(0.2))
	text.add_child(hint)
	add_child(_role_badge)


func _refresh_phase() -> void:
	if not is_instance_valid(_phase_title):
		return
	var phase := GameManager.phase
	var titles := {
		3: "TU ROL",
		4: "EL RITUAL",
		5: "NOCHE",
		6: "HEREJES",
		7: "SACERDOTE",
		8: "INQUISIDOR",
		9: "AMANECER",
		10: "EL DIOS HABLA",
		11: "DEBATE",
		12: "VOTACIÓN",
		13: "SENTENCIA",
		15: "FIN DEL RITUAL"
	}
	_phase_title.text = titles.get(phase, "GODS & LIARS")
	_phase_day.text = "RONDA %d" % maxi(1, GameManager.round_number)
	var seconds := MatchAuthority.phase_seconds_remaining()
	_phase_clock.text = "%02d:%02d" % [seconds / 60, seconds % 60]
	_phase_clock.add_theme_color_override("font_color", Color(0.9, 0.40, 0.30) if seconds <= 10 else HUD.IVORY)
	var duration := PhaseTimeoutPolicy.timeout_ms_for_phase(phase) / 1000.0
	_phase_progress.value = clampf(seconds / maxf(duration, 1.0) * 100.0, 0, 100)
	_phase_clock.visible = duration > 0
	_phase_progress.visible = duration > 0
