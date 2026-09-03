class_name RitualFlowUI
extends CanvasLayer

var _table: Node3D = null
var _phase_started_ms: int = 0
var _priest_warning_peer_id: int = 0

var _blackout: ColorRect
var _banner: Label
var _timer: Label
var _dialogue_panel: PanelContainer
var _speaker: Label
var _dialogue: Label

func setup(table: Node3D) -> void:
	_table = table

func _ready() -> void:
	layer = 5
	_build_ui()
	MatchAuthority.phase_synced.connect(_on_phase_synced)
	MatchAuthority.private_priest_warning_received.connect(_on_private_priest_warning_received)
	MatchAuthority.night_public_report_received.connect(_on_night_public_report_received)
	MatchAuthority.sacrifice_reveal_received.connect(_on_sacrifice_reveal_received)
	_phase_started_ms = Time.get_ticks_msec()
	_apply_phase(GameManager.phase)

func _process(_delta: float) -> void:
	_update_timer()
	_update_staged_dialogue()

func _build_ui() -> void:
	_blackout = ColorRect.new()
	_blackout.name = "NightBlackout"
	_blackout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_blackout.color = Color(0.0, 0.0, 0.0, 1.0)
	_blackout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_blackout)

	_banner = Label.new()
	_banner.name = "PhaseBanner"
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.position = Vector2(-260.0, 26.0)
	_banner.size = Vector2(520.0, 44.0)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 28)
	_banner.add_theme_color_override("font_color", Color(0.96, 0.92, 0.82, 1.0))
	_banner.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.025, 1.0))
	_banner.add_theme_constant_override("outline_size", 8)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)

	_timer = Label.new()
	_timer.name = "PhaseTimer"
	_timer.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_timer.position = Vector2(-100.0, 70.0)
	_timer.size = Vector2(200.0, 36.0)
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer.add_theme_font_size_override("font_size", 21)
	_timer.add_theme_color_override("font_color", Color(0.92, 0.87, 0.77, 1.0))
	_timer.add_theme_color_override("font_outline_color", Color.BLACK)
	_timer.add_theme_constant_override("outline_size", 6)
	_timer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_timer)

	_dialogue_panel = PanelContainer.new()
	_dialogue_panel.name = "GodDialogue"
	_dialogue_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_dialogue_panel.position = Vector2(-500.0, -190.0)
	_dialogue_panel.size = Vector2(1000.0, 150.0)
	_dialogue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.022, 0.026, 0.94)
	panel_style.border_color = Color(0.46, 0.35, 0.22, 0.9)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.content_margin_left = 24.0
	panel_style.content_margin_right = 24.0
	panel_style.content_margin_top = 14.0
	panel_style.content_margin_bottom = 14.0
	_dialogue_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_dialogue_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_dialogue_panel.add_child(vbox)
	_speaker = Label.new()
	_speaker.text = "DIOS"
	_speaker.add_theme_font_size_override("font_size", 17)
	_speaker.add_theme_color_override("font_color", Color(0.78, 0.62, 0.36, 1.0))
	vbox.add_child(_speaker)
	_dialogue = Label.new()
	_dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue.add_theme_font_size_override("font_size", 22)
	_dialogue.add_theme_color_override("font_color", Color(0.96, 0.94, 0.9, 1.0))
	vbox.add_child(_dialogue)

func _on_phase_synced(phase_value: int) -> void:
	_phase_started_ms = Time.get_ticks_msec()
	_apply_phase(phase_value as GameManager.MatchPhase)

func _on_private_priest_warning_received(target_peer_id: int) -> void:
	_priest_warning_peer_id = target_peer_id
	if GameManager.phase == GameManager.MatchPhase.HEALER_ACTION:
		_update_staged_dialogue()

func _on_night_public_report_received(
	_killed_peer_ids: Array[int],
	_priest_saved: bool,
	_first_night: bool
) -> void:
	if GameManager.phase == GameManager.MatchPhase.DAY_ANNOUNCEMENT:
		_update_staged_dialogue()

func _on_sacrifice_reveal_received(
	_sacrificed_peer_id: int,
	_tied: bool,
	_was_heretic: bool
) -> void:
	if GameManager.phase == GameManager.MatchPhase.SACRIFICE:
		_update_staged_dialogue()

func _apply_phase(phase: GameManager.MatchPhase) -> void:
	_banner.visible = true
	_timer.visible = PhaseTimeoutPolicy.has_timeout(phase)
	_dialogue_panel.visible = true
	_speaker.text = "DIOS"
	match phase:
		GameManager.MatchPhase.GOD_INTRO:
			_set_blackout(false)
			_banner.text = "EL RITUAL COMIENZA"
			_call_table("focus_god_camera")
		GameManager.MatchPhase.NIGHT_START:
			_set_blackout(_local_is_alive())
			_banner.text = "NOCHE %d" % GameManager.round_number
			_dialogue.text = "Están pasando cosas esta noche. Aguarda..."
			_speaker.text = ""
		GameManager.MatchPhase.HERETIC_ACTION:
			_apply_heretic_phase()
		GameManager.MatchPhase.HEALER_ACTION:
			_apply_priest_phase()
		GameManager.MatchPhase.INQUISITOR_ACTION:
			_apply_inquisitor_phase()
		GameManager.MatchPhase.NIGHT_RESOLUTION:
			_set_blackout(_local_is_alive())
			_banner.text = "LA NOCHE TERMINA"
			_dialogue.text = "El destino de esta noche se está resolviendo..."
			_speaker.text = ""
		GameManager.MatchPhase.DAY_ANNOUNCEMENT:
			_set_blackout(false)
			_banner.text = "DÍA %d" % (GameManager.round_number + 1)
			_call_table("focus_god_camera")
		GameManager.MatchPhase.DAY_DISCUSSION:
			_set_blackout(false)
			_banner.text = "DISCUSIÓN — DÍA %d" % (GameManager.round_number + 1)
			_dialogue.text = "Se abre la discusión. Tienen un minuto para debatir."
			_call_table("restore_local_camera")
		GameManager.MatchPhase.VOTING:
			_set_blackout(false)
			_banner.text = "VOTACIÓN"
			_dialogue.text = "La discusión terminó. Elijan a quién sacrificar."
			_call_table("restore_local_camera")
		GameManager.MatchPhase.SACRIFICE:
			_set_blackout(false)
			_banner.text = "SACRIFICIO"
			_call_table("focus_god_camera")
		GameManager.MatchPhase.MATCH_END:
			_set_blackout(false)
			_banner.visible = false
			_timer.visible = false
			_dialogue_panel.visible = false
		_:
			_set_blackout(false)
			_banner.visible = false
			_timer.visible = false
			_dialogue_panel.visible = false
	_update_staged_dialogue()

func _apply_heretic_phase() -> void:
	_banner.text = "LOS HEREJES SE MUEVEN"
	if not _local_is_alive():
		_set_blackout(false)
		_dialogue_panel.visible = false
		return
	if MatchAuthority.local_role == PlayerState.Role.HERETIC:
		_set_blackout(false)
		_speaker.text = ""
		_dialogue.text = (
			"Esta noche decidís vos. Elegí a la víctima junto a tu compañero."
			if MatchAuthority.is_local_heretic_decider()
			else "Tu compañero hereje decide esta noche. Usen el chat privado para coordinarse."
		)
	else:
		_set_blackout(true)
		_speaker.text = ""
		_dialogue.text = "Parece que los herejes se están moviendo. Ojalá no se acerquen a ti."

func _apply_priest_phase() -> void:
	_banner.text = "EL SACERDOTE ACTÚA"
	if not _local_is_alive():
		_set_blackout(false)
		_dialogue_panel.visible = false
		return
	if MatchAuthority.local_role == PlayerState.Role.HEALER:
		_set_blackout(false)
		_speaker.text = "DIOS"
		_update_priest_dialogue()
	elif MatchAuthority.local_role == PlayerState.Role.HERETIC:
		_set_blackout(true)
		_speaker.text = ""
		_dialogue.text = "El sacerdote está actuando. Esperemos que no encuentre a su víctima."
	else:
		_set_blackout(true)
		_speaker.text = ""
		_dialogue.text = "El sacerdote está actuando. Esperemos que encuentre a la víctima."

func _apply_inquisitor_phase() -> void:
	_banner.text = "EL INQUISIDOR HABLA CON DIOS"
	if not _local_is_alive():
		_set_blackout(false)
		_dialogue_panel.visible = false
		return
	if MatchAuthority.local_role == PlayerState.Role.INQUISITOR:
		_set_blackout(false)
		_speaker.text = "DIOS"
		if GameManager.round_number == 1:
			_dialogue.text = (
				"Tu trabajo será descubrir a los herejes. Podrás hacer una pregunta por noche, "
				+ "pero no puedo intervenir demasiado en el mundo humano. Esta noche descansa; "
				+ "mañana busca pistas en los debates."
			)
		else:
			_dialogue.text = "Elegí una máscara. Esta noche conocerás la verdad que se esconde detrás de ella."
	else:
		_set_blackout(true)
		_speaker.text = ""
		_dialogue.text = "El inquisidor está hablando con Dios. Mañana sabrá la verdad debajo de la máscara de uno de ustedes."

func _update_staged_dialogue() -> void:
	var elapsed := float(Time.get_ticks_msec() - _phase_started_ms) / 1000.0
	match GameManager.phase:
		GameManager.MatchPhase.GOD_INTRO:
			if elapsed < 5.5:
				_dialogue.text = "Hay dos herejes entre nosotros. Entre ustedes también se encuentran un Sacerdote y un Inquisidor."
			else:
				_dialogue.text = "Vayan a descansar. Mañana nos reuniremos."
				_call_table("restore_local_camera")
		GameManager.MatchPhase.HEALER_ACTION:
			if MatchAuthority.local_role == PlayerState.Role.HEALER and _local_is_alive():
				_update_priest_dialogue()
		GameManager.MatchPhase.DAY_ANNOUNCEMENT:
			_update_day_announcement(elapsed)
		GameManager.MatchPhase.SACRIFICE:
			_update_sacrifice_dialogue(elapsed)

func _update_priest_dialogue() -> void:
	if GameManager.round_number == 1:
		if _priest_warning_peer_id <= 0:
			_dialogue.text = "Voy a ayudarte. Presta atención: esta noche los herejes elegirán una víctima."
			return
		var victim_name := _peer_name(_priest_warning_peer_id)
		var local_peer_id := multiplayer.get_unique_id() if multiplayer.multiplayer_peer != null else 0
		if _priest_warning_peer_id == local_peer_id:
			_dialogue.text = "Te quieren matar a ti. Atiende tus heridas, sobrevive y salva a mis hijos."
		else:
			_dialogue.text = "Voy a ayudarte. Quieren matar a %s. Ve a salvarlo. Solo te lo diré hoy; tendrás que salvar a mis hijos." % victim_name
	else:
		_dialogue.text = "¿A quién irás a salvar hoy? También puedes protegerte a ti mismo una vez más."

func _update_day_announcement(elapsed: float) -> void:
	var killed := MatchAuthority.last_night_killed_peer_ids
	if not killed.is_empty():
		if elapsed < 3.0:
			_dialogue.text = "Lamentablemente... alguien murió anoche."
		else:
			_dialogue.text = "%s murió anoche." % _peer_name(int(killed[0]))
		return
	if MatchAuthority.last_night_priest_saved or MatchAuthority.last_night_was_first:
		_dialogue.text = "Esta noche el Sacerdote salvó a una víctima. Los herejes están atacando."
	else:
		_dialogue.text = "La noche terminó sin víctimas."

func _update_sacrifice_dialogue(elapsed: float) -> void:
	if MatchAuthority.last_sacrificed_peer_id <= 0:
		_dialogue.text = "No hubo un sacrificio válido."
		return
	if MatchAuthority.last_sacrifice_was_tie and elapsed < 2.5:
		_dialogue.text = "El voto terminó en empate. El destino lo decidirá."
		return
	_dialogue.text = (
		"Un Hereje fue sacrificado."
		if MatchAuthority.last_sacrifice_was_heretic
		else "Un inocente fue sacrificado."
	)

func _update_timer() -> void:
	if not _timer.visible:
		return
	var seconds := MatchAuthority.phase_seconds_remaining()
	_timer.text = "%02d:%02d" % [seconds / 60, seconds % 60]

func _set_blackout(value: bool) -> void:
	_blackout.visible = value and not MatchAuthority.is_local_ghost()

func _local_is_alive() -> bool:
	if multiplayer.multiplayer_peer == null:
		return true
	return MatchAuthority.is_peer_publicly_alive(multiplayer.get_unique_id())

func _call_table(method: StringName) -> void:
	if _table != null and is_instance_valid(_table) and _table.has_method(method):
		_table.call(method)

func _peer_name(peer_id: int) -> String:
	var data: Dictionary = NetworkManager.peers.get(peer_id, {})
	var display_name := str(data.get("display_name", "")).strip_edges()
	return display_name if not display_name.is_empty() else "Jugador %d" % peer_id
