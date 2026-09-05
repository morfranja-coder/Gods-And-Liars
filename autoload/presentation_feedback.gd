extends Node

const FEEDBACK_SECONDS := 6.0

var _feedback_layer: CanvasLayer = null
var _feedback_root: Control = null
var _feedback_title: Label = null
var _feedback_message: Label = null
var _feedback_generation: int = 0
var _pending_sacrifice_text: String = ""

func _ready() -> void:
	MatchAuthority.sacrifice_reveal_received.connect(_on_sacrifice_reveal_received)
	MatchAuthority.private_investigation_received.connect(_on_private_investigation_received)
	MatchAuthority.phase_synced.connect(_on_phase_synced)

func _process(_delta: float) -> void:
	if GameManager.phase == GameManager.MatchPhase.SACRIFICE:
		_hide_legacy_sacrifice_panels()
	_refresh_inquisitor_selection()

func _on_sacrifice_reveal_received(
	sacrificed_peer_id: int,
	_tied: bool,
	was_heretic: bool
) -> void:
	if sacrificed_peer_id <= 0:
		_pending_sacrifice_text = "El juicio terminó sin sacrificio."
	else:
		_pending_sacrifice_text = (
			"Se sacrificó a un Hereje."
			if was_heretic
			else "Se sacrificó a un inocente."
		)

func _on_private_investigation_received(target_peer_id: int, is_heretic: bool) -> void:
	if MatchAuthority.local_role != PlayerState.Role.INQUISITOR:
		return
	var player_name := _peer_name(target_peer_id)
	var text := (
		"%s ES HEREJE." % player_name
		if is_heretic
		else "%s NO ES HEREJE." % player_name
	)
	_show_feedback("REVELACIÓN PRIVADA DEL INQUISIDOR", text, FEEDBACK_SECONDS)

func _on_phase_synced(phase_value: int) -> void:
	if phase_value != GameManager.MatchPhase.SACRIFICE:
		return
	call_deferred("_present_sacrifice_result")

func _present_sacrifice_result() -> void:
	_hide_legacy_sacrifice_panels()
	var text := _pending_sacrifice_text
	if text.is_empty():
		if MatchAuthority.last_sacrificed_peer_id <= 0:
			text = "El juicio terminó sin sacrificio."
		else:
			text = (
				"Se sacrificó a un Hereje."
				if MatchAuthority.last_sacrifice_was_heretic
				else "Se sacrificó a un inocente."
			)
	_show_feedback("EL DIOS DICTA SENTENCIA", text, FEEDBACK_SECONDS)

func _hide_legacy_sacrifice_panels() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var day_vote_panel := scene.get_node_or_null("DayVoteUI/Panel") as Control
	if day_vote_panel != null:
		day_vote_panel.visible = false
	var legacy_subtitles := scene.get_node_or_null("NightActionUI/MinimalNarrative") as Control
	if legacy_subtitles != null:
		legacy_subtitles.visible = false

func _refresh_inquisitor_selection() -> void:
	if GameManager.phase != GameManager.MatchPhase.INQUISITOR_ACTION:
		return
	if MatchAuthority.local_role != PlayerState.Role.INQUISITOR:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var night_ui := scene.get_node_or_null("NightActionUI")
	var cards_grid := scene.get_node_or_null("NightActionUI/Panel/VBox/CardsScroll/CardsGrid")
	if night_ui == null or cards_grid == null:
		return
	var selected_peer_id := int(night_ui.get("selected_peer_id"))
	for child in cards_grid.get_children():
		if child is not Button:
			continue
		var card := child as Button
		var peer_id := int(card.get_meta("peer_id", 0))
		if selected_peer_id <= 0:
			card.modulate = Color.WHITE
		elif peer_id == selected_peer_id:
			card.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			card.modulate = Color(0.48, 0.48, 0.48, 0.82)

func _show_feedback(title: String, text: String, duration_seconds: float) -> void:
	_ensure_feedback_overlay()
	_feedback_generation += 1
	var generation := _feedback_generation
	_feedback_title.text = title
	_feedback_message.text = text
	_feedback_root.visible = true
	_hide_feedback_after(generation, duration_seconds)

func _hide_feedback_after(generation: int, duration_seconds: float) -> void:
	await get_tree().create_timer(duration_seconds).timeout
	if generation != _feedback_generation:
		return
	if _feedback_root != null:
		_feedback_root.visible = false

func _ensure_feedback_overlay() -> void:
	if _feedback_layer != null:
		return
	_feedback_layer = CanvasLayer.new()
	_feedback_layer.name = "PresentationFeedbackLayer"
	_feedback_layer.layer = 120
	add_child(_feedback_layer)

	_feedback_root = Control.new()
	_feedback_root.name = "PresentationFeedback"
	_feedback_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_feedback_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feedback_layer.add_child(_feedback_root)

	var container := VBoxContainer.new()
	container.anchor_left = 0.5
	container.anchor_top = 1.0
	container.anchor_right = 0.5
	container.anchor_bottom = 1.0
	container.offset_left = -410.0
	container.offset_top = -145.0
	container.offset_right = 410.0
	container.offset_bottom = -35.0
	container.alignment = BoxContainer.ALIGNMENT_END
	container.add_theme_constant_override("separation", 5)
	_feedback_root.add_child(container)

	_feedback_title = Label.new()
	_feedback_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_title.add_theme_font_size_override("font_size", 14)
	_feedback_title.add_theme_color_override("font_color", Color(0.76, 0.67, 0.48, 1.0))
	_feedback_title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.98))
	_feedback_title.add_theme_constant_override("outline_size", 5)
	container.add_child(_feedback_title)

	_feedback_message = Label.new()
	_feedback_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_feedback_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback_message.add_theme_font_size_override("font_size", 22)
	_feedback_message.add_theme_color_override("font_color", Color(0.96, 0.93, 0.86, 1.0))
	_feedback_message.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_feedback_message.add_theme_constant_override("outline_size", 7)
	container.add_child(_feedback_message)

	_feedback_root.visible = false

func _peer_name(peer_id: int) -> String:
	var data: Dictionary = NetworkManager.peers.get(peer_id, {})
	var display_name := str(data.get("display_name", ""))
	return display_name if not display_name.is_empty() else "Acólito %d" % peer_id
