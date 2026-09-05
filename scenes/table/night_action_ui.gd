extends CanvasLayer

var selected_peer_id: int = 0
var _table: Node = null
var _submission_pending: bool = false
var _submitted_phase: int = -1
var _cards_by_peer: Dictionary = {}
var _last_timer_second: int = -1
var _priest_warning_target_peer_id: int = 0
var _investigation_result_text: String = ""
var _god_camera_active: bool = false
var _subtitle_root: Control = null
var _subtitle_title: Label = null
var _subtitle_message: Label = null
var _subtitle_timer: Label = null

@onready var black_overlay: ColorRect = $BlackOverlay
@onready var panel: PanelContainer = $Panel
@onready var phase_label: Label = $Panel/VBox/PhaseLabel
@onready var timer_label: Label = $Panel/VBox/TimerLabel
@onready var message_label: Label = $Panel/VBox/MessageLabel
@onready var target_label: Label = $Panel/VBox/TargetLabel
@onready var cards_scroll: ScrollContainer = $Panel/VBox/CardsScroll
@onready var cards_grid: GridContainer = $Panel/VBox/CardsScroll/CardsGrid
@onready var confirm_button: Button = $Panel/VBox/ConfirmButton
@onready var result_label: Label = $Panel/VBox/ResultLabel

func _ready() -> void:
	_table = get_parent()
	_build_minimal_subtitles()
	confirm_button.pressed.connect(_on_confirm_pressed)
	MatchAuthority.phase_synced.connect(_on_phase_synced)
	MatchAuthority.heretic_decider_changed.connect(_on_heretic_decider_changed)
	MatchAuthority.night_action_result_received.connect(_on_night_action_result_received)
	MatchAuthority.private_priest_warning_received.connect(_on_private_priest_warning_received)
	MatchAuthority.private_investigation_received.connect(_on_private_investigation_received)
	MatchAuthority.night_public_report_received.connect(_on_night_public_report_received)
	MatchAuthority.sacrifice_reveal_received.connect(_on_sacrifice_reveal_received)
	_refresh_for_phase()


func _build_minimal_subtitles() -> void:
	_subtitle_root = Control.new()
	_subtitle_root.name = "MinimalNarrative"
	_subtitle_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_subtitle_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_subtitle_root)

	_subtitle_timer = Label.new()
	_subtitle_timer.name = "NarrativeTimer"
	_subtitle_timer.anchor_left = 0.5
	_subtitle_timer.anchor_right = 0.5
	_subtitle_timer.offset_left = -60.0
	_subtitle_timer.offset_right = 60.0
	_subtitle_timer.offset_top = 28.0
	_subtitle_timer.offset_bottom = 62.0
	_subtitle_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_timer.add_theme_font_size_override("font_size", 22)
	_subtitle_timer.add_theme_color_override("font_color", Color(0.88, 0.82, 0.69, 1.0))
	_subtitle_timer.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	_subtitle_timer.add_theme_constant_override("outline_size", 6)
	_subtitle_root.add_child(_subtitle_timer)

	var subtitles := VBoxContainer.new()
	subtitles.name = "SubtitleContainer"
	subtitles.anchor_left = 0.5
	subtitles.anchor_top = 1.0
	subtitles.anchor_right = 0.5
	subtitles.anchor_bottom = 1.0
	subtitles.offset_left = -390.0
	subtitles.offset_top = -150.0
	subtitles.offset_right = 390.0
	subtitles.offset_bottom = -30.0
	subtitles.alignment = BoxContainer.ALIGNMENT_END
	subtitles.add_theme_constant_override("separation", 4)
	_subtitle_root.add_child(subtitles)

	_subtitle_title = Label.new()
	_subtitle_title.name = "NarrativeTitle"
	_subtitle_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_title.add_theme_font_size_override("font_size", 14)
	_subtitle_title.add_theme_color_override("font_color", Color(0.72, 0.65, 0.50, 1.0))
	_subtitle_title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	_subtitle_title.add_theme_constant_override("outline_size", 5)
	subtitles.add_child(_subtitle_title)

	_subtitle_message = Label.new()
	_subtitle_message.name = "NarrativeMessage"
	_subtitle_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_message.add_theme_font_size_override("font_size", 21)
	_subtitle_message.add_theme_color_override("font_color", Color(0.94, 0.91, 0.84, 1.0))
	_subtitle_message.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_subtitle_message.add_theme_constant_override("outline_size", 7)
	subtitles.add_child(_subtitle_message)

	phase_label.visible = false
	timer_label.visible = false
	message_label.visible = false


func _sync_minimal_subtitles() -> void:
	if _subtitle_root == null:
		return

	if MatchAuthority.is_local_ghost():
		_subtitle_root.visible = false
		return

	var phase := GameManager.phase

	var narrative_phase := phase in [
		GameManager.MatchPhase.GOD_INTRO,
		GameManager.MatchPhase.DAY_ANNOUNCEMENT,
		GameManager.MatchPhase.SACRIFICE,
	]

	var night_info_phase := (
		phase == GameManager.MatchPhase.NIGHT_START
		or NightPhaseRules.is_action_phase(phase)
	)

	var show_subtitles := narrative_phase or night_info_phase
	_subtitle_root.visible = show_subtitles

	if not show_subtitles:
		return

	_subtitle_title.text = _phase_title(phase)
	_subtitle_message.text = message_label.text


func _update_minimal_timer(seconds: int) -> void:
	if _subtitle_timer == null:
		return

	var phase := GameManager.phase

	var timed_action := (
		phase == GameManager.MatchPhase.HERETIC_ACTION
		or phase == GameManager.MatchPhase.HEALER_ACTION
		or phase == GameManager.MatchPhase.INQUISITOR_ACTION
	)

	_subtitle_timer.visible = timed_action and seconds > 0
	_subtitle_timer.text = str(seconds) if timed_action and seconds > 0 else ""


func _process(_delta: float) -> void:
	if MatchAuthority.is_local_ghost():
		panel.visible = false

		# El fantasma sigue viendo la secuencia nocturna.
		black_overlay.visible = _should_show_black_overlay()

		if _subtitle_root != null:
			_subtitle_root.visible = (
				GameManager.phase == GameManager.MatchPhase.NIGHT_START
				or NightPhaseRules.is_action_phase(GameManager.phase)
				or GameManager.phase == GameManager.MatchPhase.DAY_ANNOUNCEMENT
				or GameManager.phase == GameManager.MatchPhase.SACRIFICE
			)

		var ghost_seconds := MatchAuthority.phase_seconds_remaining()
		_update_minimal_timer(ghost_seconds)
		_refresh_narrative()
		return
	var seconds := MatchAuthority.phase_seconds_remaining()
	if seconds != _last_timer_second:
		_last_timer_second = seconds
		_refresh_timer(seconds)
	_refresh_narrative()

func _clear_narrative_surface() -> void:
	message_label.text = ""
	phase_label.text = ""

	if _subtitle_message != null:
		_subtitle_message.text = ""

	if _subtitle_title != null:
		_subtitle_title.text = ""

	if _subtitle_root != null:
		_subtitle_root.visible = false



func _on_phase_synced(_phase: int) -> void:
	_clear_narrative_surface()
	selected_peer_id = 0
	_submission_pending = false
	_submitted_phase = -1
	_last_timer_second = -1
	result_label.text = ""
	_rebuild_action_cards()
	_refresh_for_phase()

func _on_heretic_decider_changed(_peer_id: int) -> void:
	if GameManager.phase == GameManager.MatchPhase.HERETIC_ACTION:
		_rebuild_action_cards()
		_refresh_for_phase()

func _on_confirm_pressed() -> void:
	if not _valid_selected_target():
		result_label.text = "Objetivo inválido. Elegí otra máscara."
		return
	_submission_pending = true
	_submitted_phase = int(GameManager.phase)
	result_label.text = "Enviando decisión..."
	MatchAuthority.submit_local_night_target(selected_peer_id)
	_refresh_for_phase()

func _on_night_action_result_received(accepted: bool, target_peer_id: int) -> void:
	if _submitted_phase != int(GameManager.phase):
		return
	_submission_pending = false
	if accepted:
		selected_peer_id = target_peer_id
		result_label.text = "Decisión registrada. Podés cambiarla hasta que termine el tiempo."
	else:
		result_label.text = "Ese objetivo no está permitido. Elegí otro."
	_update_card_selection()
	_refresh_for_phase()

func _on_private_priest_warning_received(target_peer_id: int) -> void:
	_priest_warning_target_peer_id = target_peer_id
	if GameManager.phase == GameManager.MatchPhase.HEALER_ACTION:
		_refresh_narrative()

func _on_private_investigation_received(target_peer_id: int, is_heretic: bool) -> void:
	var name := _peer_name(target_peer_id)
	_investigation_result_text = (
		"Dios te revela la verdad: %s ES HEREJE." % name
		if is_heretic
		else "Dios te revela la verdad: %s NO es Hereje." % name
	)
	result_label.text = _investigation_result_text

func _on_night_public_report_received(
	_killed_peer_ids: Array[int],
	_priest_saved: bool,
	_first_night: bool
) -> void:
	_refresh_narrative()

func _on_sacrifice_reveal_received(
	_sacrificed_peer_id: int,
	_tied: bool,
	_was_heretic: bool
) -> void:
	_refresh_narrative()

func _refresh_for_phase() -> void:
	var can_act := _local_can_act_in_phase()
	var action_phase := _phase_uses_target_cards()

	# El cuadro grande solo existe cuando realmente hay que elegir.
	panel.visible = (
		not MatchAuthority.is_local_ghost()
		and can_act
		and action_phase
	)

	black_overlay.visible = _should_show_black_overlay()

	phase_label.visible = false
	timer_label.visible = false
	message_label.visible = false

	_refresh_action_controls()
	_refresh_narrative()
	_sync_minimal_subtitles()
	_force_action_ui_input_state()

	if _table != null and _table.has_method("_update_camera_input_state"):
		_table.call_deferred("_update_camera_input_state")

func _refresh_action_controls() -> void:
	var phase := GameManager.phase
	var can_act := _local_can_act_in_phase()
	cards_scroll.visible = can_act and _phase_uses_target_cards()
	target_label.visible = cards_scroll.visible
	confirm_button.visible = false
	confirm_button.disabled = _submission_pending or not _valid_selected_target()
	if cards_scroll.visible:
		target_label.text = (
			"Objetivo: %s" % _peer_name(selected_peer_id)
			if selected_peer_id > 0
			else "Elegí una máscara"
		)
	if confirm_button.visible and not confirm_button.disabled:
		confirm_button.grab_focus()
	if phase not in [
		GameManager.MatchPhase.HERETIC_ACTION,
		GameManager.MatchPhase.HEALER_ACTION,
		GameManager.MatchPhase.INQUISITOR_ACTION,
	]:
		cards_scroll.visible = false
		target_label.visible = false
		confirm_button.visible = false

func _refresh_timer(seconds: int) -> void:
	timer_label.visible = false
	_update_minimal_timer(seconds)

func _refresh_narrative() -> void:
	message_label.text = ""
	phase_label.text = ""

	var phase: GameManager.MatchPhase = GameManager.phase

	phase_label.text = _phase_title(phase)

	match phase:
		GameManager.MatchPhase.GOD_INTRO:
			_show_god_intro()

		GameManager.MatchPhase.NIGHT_START:
			_set_god_camera(false)

			message_label.text = (
				"ESTÁN PASANDO COSAS ESTA NOCHE.\n"
				+ "Aguardá..."
			)

		GameManager.MatchPhase.HERETIC_ACTION:
			_set_god_camera(false)
			message_label.text = _heretic_phase_message()

		GameManager.MatchPhase.HEALER_ACTION:
			_set_god_camera(true)
			message_label.text = _priest_phase_message()

		GameManager.MatchPhase.INQUISITOR_ACTION:
			_set_god_camera(false)
			message_label.text = _inquisitor_phase_message()

		GameManager.MatchPhase.DAY_ANNOUNCEMENT:
			_show_day_announcement()

		GameManager.MatchPhase.SACRIFICE:
			_show_sacrifice_narration()

		_:
			_set_god_camera(false)
			message_label.text = ""
			phase_label.text = ""

	_sync_minimal_subtitles()

func _show_god_intro() -> void:
	var elapsed := _phase_elapsed_seconds()
	if elapsed < 8.5:
		_set_god_camera(true)
		message_label.text = (
			"Entre nosotros se ocultan DOS HEREJES. "
			+ "También caminan entre ustedes un SACERDOTE y un INQUISIDOR."
		)
	else:
		_set_god_camera(false)
		message_label.text = "Vayan a descansar. Mañana nos reuniremos."

func _show_day_announcement() -> void:
	_set_god_camera(true)
	var elapsed := _phase_elapsed_seconds()
	var killed := MatchAuthority.last_night_killed_peer_ids
	if not killed.is_empty():
		if elapsed < 3.0:
			message_label.text = "Lamentablemente... alguien murió anoche."
		else:
			message_label.text = "%s murió anoche." % _peer_name(killed[0])
		return
	if MatchAuthority.last_night_priest_saved:
		message_label.text = _priest_saved_announcement()
		return
	message_label.text = "La noche terminó sin víctimas. Pero no bajen la guardia."

func _priest_saved_announcement() -> String:
	if MatchAuthority.last_night_was_first:
		return (
			"Hubo un intento de asesinato esta noche. "
			+ "El Sacerdote salvó a la víctima. Los Herejes están atacando."
		)
	return "Esta noche el Sacerdote salvó a una víctima. Los Herejes están atacando."

func _show_sacrifice_narration() -> void:
	_set_god_camera(true)

	var peer_id: int = (
		MatchAuthority.last_sacrificed_peer_id
	)

	if peer_id <= 0:
		message_label.text = (
			"El juicio terminó sin sacrificio."
		)
		return

	message_label.text = (
		"Se sacrificó a un Hereje."
		if MatchAuthority.last_sacrifice_was_heretic
		else "Se sacrificó a un inocente."
	)

func _heretic_phase_message() -> String:
	if MatchAuthority.local_role != PlayerState.Role.HERETIC:
		return "Parece que los Herejes se están moviendo. Ojalá no se acerquen a ti."
	if MatchAuthority.is_local_heretic_decider():
		return "Esta noche decidís vos. Elegí a quién atacar antes de que termine el tiempo."
	return "Tu compañero Hereje decide esta noche. Usen el chat privado para acordar la víctima."

func _priest_phase_message() -> String:
	if MatchAuthority.local_role == PlayerState.Role.HEALER:
		return _local_priest_message()
	if MatchAuthority.local_role == PlayerState.Role.HERETIC:
		return "El Sacerdote está actuando. Esperemos que no encuentre a su víctima."
	return "El Sacerdote está actuando. Esperemos que encuentre a la víctima."

func _local_priest_message() -> String:
	if GameManager.round_number != 1:
		return "¿A quién irás a salvar hoy? Elegí una máscara antes de que termine el tiempo."
	var victim := _priest_warning_target_peer_id
	if victim <= 0:
		return "Voy a ayudarte esta noche. Los Herejes ya eligieron a una víctima."
	if victim == _local_peer_id():
		return (
			"Te quieren matar. Atiende tus heridas, sobrevive y salva a mis hijos. "
			+ "Solo hoy te diré a quién atacan."
		)
	return (
		"Voy a ayudarte. Quieren matar a %s. Ve a salvarlo. " % _peer_name(victim)
		+ "Solo hoy te diré a quién atacan; tendrás que salvar a mis hijos."
	)

func _inquisitor_phase_message() -> String:
	if MatchAuthority.local_role == PlayerState.Role.INQUISITOR:
		if GameManager.round_number == 1:
			return (
				"Tu trabajo será descubrir a los Herejes. Podrás hacer una pregunta por noche; "
				+ "no puedo intervenir demasiado en el mundo humano. Esta noche descansa y piensa "
				+ "bien en tu pregunta de mañana. Busca pistas en los debates."
			)
		return "Elegí una máscara. Mañana conocerás la verdad que se oculta detrás de ella."
	return (
		"El Inquisidor está hablando con Dios. "
		+ "Mañana sabrá la verdad debajo de la máscara de uno de ustedes."
	)

func _should_show_black_overlay() -> bool:
	var phase := GameManager.phase

	var night_phase := (
		phase == GameManager.MatchPhase.NIGHT_START
		or NightPhaseRules.is_action_phase(phase)
	)

	if not night_phase:
		return false

	# Los fantasmas tambien observan la secuencia nocturna.
	if MatchAuthority.is_local_ghost():
		return true

	# Los Herejes vivos necesitan ver su interfaz cuando actuan.
	return MatchAuthority.local_role != PlayerState.Role.HERETIC

func _local_can_act_in_phase() -> bool:
	var can_act := not MatchAuthority.is_local_ghost()
	var local_peer_id := _local_peer_id()
	can_act = can_act and local_peer_id > 0
	can_act = can_act and MatchAuthority.is_peer_publicly_alive(local_peer_id)
	var required_role := NightPhaseRules.role_for_phase(GameManager.phase)
	can_act = can_act and required_role == MatchAuthority.local_role
	if can_act and required_role == PlayerState.Role.HERETIC:
		can_act = MatchAuthority.is_local_heretic_decider()
	if can_act and required_role == PlayerState.Role.HEALER and GameManager.round_number == 1:
		can_act = false
	if can_act and required_role == PlayerState.Role.INQUISITOR and GameManager.round_number == 1:
		can_act = false
	return can_act

func _phase_uses_target_cards() -> bool:
	return GameManager.phase in [
		GameManager.MatchPhase.HERETIC_ACTION,
		GameManager.MatchPhase.HEALER_ACTION,
		GameManager.MatchPhase.INQUISITOR_ACTION,
	]

func _rebuild_action_cards() -> void:
	for child in cards_grid.get_children():
		child.queue_free()
	_cards_by_peer.clear()
	if not _local_can_act_in_phase() or not _phase_uses_target_cards():
		return
	var peer_ids := NetworkManager.peers.keys()
	peer_ids.sort_custom(func(a, b):
		var seat_a := int((NetworkManager.peers[a] as Dictionary).get("seat_id", 99))
		var seat_b := int((NetworkManager.peers[b] as Dictionary).get("seat_id", 99))
		return seat_a < seat_b
	)
	for raw_peer_id in peer_ids:
		var peer_id := int(raw_peer_id)
		if not _target_allowed_for_local_role(peer_id):
			continue
		var card := PlayerPortraitCards.create_player_button(peer_id, Vector2(175, 185))
		card.toggle_mode = true
		card.focus_mode = Control.FOCUS_ALL
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.focus_entered.connect(_focus_night_target.bind(peer_id))
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.pressed.connect(_on_card_pressed.bind(peer_id))
		cards_grid.add_child(card)
		_cards_by_peer[peer_id] = card
	_update_card_selection()

	if not _cards_by_peer.is_empty():
		call_deferred("_focus_first_night_card")


func _on_card_pressed(peer_id: int) -> void:
	if not _target_allowed_for_local_role(peer_id):
		return

	selected_peer_id = peer_id
	_update_card_selection()

	# ESPACIO sobre la tarjeta confirma directamente.
	if _valid_selected_target():
		_on_confirm_pressed()


func _focus_night_target(peer_id: int) -> void:
	if not _target_allowed_for_local_role(peer_id):
		return

	selected_peer_id = peer_id
	_update_card_selection()

	target_label.text = (
		"WASD  Elegir     ESPACIO  Confirmar
"
		+ "Objetivo: %s" % _peer_name(peer_id)
	)


func _focus_first_night_card() -> void:
	for child in cards_grid.get_children():
		if child is Button:
			var button: Button = child as Button
			if not button.disabled:
				button.grab_focus()
				return

func _update_card_selection() -> void:
	for raw_peer_id in _cards_by_peer.keys():
		var peer_id := int(raw_peer_id)
		var card := _cards_by_peer[raw_peer_id] as Button
		if card != null:
			card.button_pressed = peer_id == selected_peer_id

func _target_allowed_for_local_role(peer_id: int) -> bool:
	if peer_id <= 0 or not MatchAuthority.is_peer_publicly_alive(peer_id):
		return false
	var local_peer_id := _local_peer_id()
	match MatchAuthority.local_role:
		PlayerState.Role.HERETIC:
			return peer_id != local_peer_id and peer_id != MatchAuthority.local_heretic_teammate_peer_id
		PlayerState.Role.INQUISITOR:
			return peer_id != local_peer_id
		PlayerState.Role.HEALER:
			return true
		_:
			return false

func _valid_selected_target() -> bool:
	return selected_peer_id > 0 and _target_allowed_for_local_role(selected_peer_id)

func _phase_title(phase: GameManager.MatchPhase) -> String:
	var title := "RITUAL"
	match phase:
		GameManager.MatchPhase.GOD_INTRO:
			title = "EL DIOS HABLA"
		GameManager.MatchPhase.NIGHT_START:
			title = "NOCHE %d" % GameManager.round_number
		GameManager.MatchPhase.HERETIC_ACTION:
			title = "NOCHE — HEREJES"
		GameManager.MatchPhase.HEALER_ACTION:
			title = "NOCHE — SACERDOTE"
		GameManager.MatchPhase.INQUISITOR_ACTION:
			title = "NOCHE — INQUISIDOR"
		GameManager.MatchPhase.DAY_ANNOUNCEMENT:
			title = "DÍA %d" % (GameManager.round_number + 1)
		GameManager.MatchPhase.SACRIFICE:
			title = "EL DIOS DICTA SENTENCIA"
	return title

func _phase_elapsed_seconds() -> float:
	var duration_ms: int = PhaseTimeoutPolicy.timeout_ms_for_phase(GameManager.phase)
	if duration_ms <= 0:
		return 0.0
	var remaining_ms := MatchAuthority.phase_seconds_remaining() * 1000
	return maxf(0.0, float(duration_ms - remaining_ms) / 1000.0)

func _set_god_camera(enabled: bool) -> void:
	if _god_camera_active == enabled:
		return
	_god_camera_active = enabled
	if _table == null:
		return
	if enabled and _table.has_method("focus_camera_on_god"):
		_table.call("focus_camera_on_god")
	elif not enabled and _table.has_method("restore_local_player_camera"):
		_table.call("restore_local_player_camera")


func _force_action_ui_input_state() -> void:
	var active := (
		panel.visible
		and cards_scroll.visible
		and _local_can_act_in_phase()
	)

	if active:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

		if _table != null:
			var camera: Object = _table.get("table_camera") as Object
			if camera != null and camera.has_method("set_look_enabled"):
				camera.call("set_look_enabled", false)



func blocks_gameplay_input() -> bool:
	if MatchAuthority.is_local_ghost():
		return false

	return (
		panel.visible
		and cards_scroll.visible
		and _local_can_act_in_phase()
	)



func _local_peer_id() -> int:
	return multiplayer.get_unique_id() if multiplayer.multiplayer_peer != null else 0

func _peer_name(peer_id: int) -> String:
	if peer_id <= 0:
		return "nadie"
	var data: Dictionary = NetworkManager.peers.get(peer_id, {})
	var name := str(data.get("display_name", ""))
	return name if not name.is_empty() else "Acólito %d" % peer_id
