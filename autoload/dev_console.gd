extends CanvasLayer

const TOGGLE_KEY_F1 := KEY_F1
const TOGGLE_UNICODE_BACKTICK := 96
const MAX_HISTORY := 40

var _root: Control
var _panel: PanelContainer
var _output: RichTextLabel
var _input: LineEdit
var _history: Array[String] = []
var _history_index := 0
var _is_open := false
var _previous_mouse_mode := Input.MOUSE_MODE_CAPTURED

func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	layer = 1000
	_build_ui()
	_set_open(false)
	_write_line("Developer Console lista. F1 o ` para abrir/cerrar.")
	_write_line("Escribi 'help' para ver comandos.")

func _process(_delta: float) -> void:
	if _is_open and Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _input(event: InputEvent) -> void:
	if event is not InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	var toggles_console := (
		key_event.keycode == TOGGLE_KEY_F1
		or key_event.physical_keycode == TOGGLE_KEY_F1
		or key_event.unicode == TOGGLE_UNICODE_BACKTICK
	)
	if toggles_console:
		_set_open(not _is_open)
		get_viewport().set_input_as_handled()
		return
	if _is_open and key_event.keycode == KEY_ESCAPE:
		_set_open(false)
		get_viewport().set_input_as_handled()

func _build_ui() -> void:
	_root = Control.new()
	_root.name = "DeveloperConsoleRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	_panel = PanelContainer.new()
	_panel.name = "DeveloperConsolePanel"
	_panel.anchor_right = 1.0
	_panel.offset_left = 18.0
	_panel.offset_top = 18.0
	_panel.offset_right = -18.0
	_panel.offset_bottom = 390.0
	_root.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var title := Label.new()
	title.text = "GODS & LIARS — DEVELOPER CONSOLE [DEBUG ONLY]"
	title.add_theme_font_size_override("font_size", 18)
	column.add_child(title)

	_output = RichTextLabel.new()
	_output.custom_minimum_size = Vector2(0.0, 285.0)
	_output.bbcode_enabled = true
	_output.scroll_active = true
	_output.scroll_following = true
	_output.selection_enabled = true
	column.add_child(_output)

	_input = LineEdit.new()
	_input.placeholder_text = "Comando...  (help para ayuda)"
	_input.clear_button_enabled = true
	_input.text_submitted.connect(_on_command_submitted)
	_input.gui_input.connect(_on_input_gui_input)
	column.add_child(_input)

func _set_open(value: bool) -> void:
	_is_open = value
	if _root != null:
		_root.visible = value
	if value:
		_previous_mouse_mode = Input.get_mouse_mode()
		InputBindings.set_text_entry_active(true)
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if _input != null:
			_input.grab_focus()
	else:
		InputBindings.set_text_entry_active(false)
		if _input != null:
			_input.release_focus()
		Input.set_mouse_mode(_previous_mouse_mode)

func _on_command_submitted(raw_text: String) -> void:
	var command_line := raw_text.strip_edges()
	_input.clear()
	if command_line.is_empty():
		return
	_push_history(command_line)
	_write_line("> " + command_line)
	_execute_command(command_line)
	call_deferred("_refocus_input")

func _on_input_gui_input(event: InputEvent) -> void:
	if event is not InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_UP:
		_history_previous()
		accept_event()
	elif key_event.keycode == KEY_DOWN:
		_history_next()
		accept_event()

func _refocus_input() -> void:
	if _is_open and _input != null:
		_input.grab_focus()

func _push_history(command_line: String) -> void:
	if _history.is_empty() or _history.back() != command_line:
		_history.append(command_line)
	if _history.size() > MAX_HISTORY:
		_history.pop_front()
	_history_index = _history.size()

func _history_previous() -> void:
	if _history.is_empty():
		return
	_history_index = maxi(0, _history_index - 1)
	_input.text = _history[_history_index]
	_input.caret_column = _input.text.length()

func _history_next() -> void:
	if _history.is_empty():
		return
	_history_index = mini(_history.size(), _history_index + 1)
	_input.text = "" if _history_index >= _history.size() else _history[_history_index]
	_input.caret_column = _input.text.length()

func _execute_command(command_line: String) -> void:
	var parts := command_line.split(" ", false)
	if parts.is_empty():
		return
	var command := parts[0].to_lower()
	var args := parts.slice(1)
	match command:
		"help", "?":
			_print_help()
		"clear", "cls":
			_output.clear()
		"state":
			_print_state()
		"players":
			_print_players()
		"fps":
			_write_line("FPS: %.1f" % Performance.get_monitor(Performance.TIME_FPS))
		"phase":
			_command_phase(args)
		"round":
			_command_round(args)
		"role":
			_command_role(args)
		"ghost":
			_command_ghost()
		"revive":
			_command_revive()
		"nightresult":
			_command_night_result(args)
		"godcamera":
			_command_camera(true)
		"playercamera":
			_command_camera(false)
		_:
			_write_error("Comando desconocido: %s. Usa 'help'." % command)

func _print_help() -> void:
	_write_line("Comandos disponibles:")
	_write_line("  help                     - muestra esta ayuda")
	_write_line("  clear                    - limpia la consola")
	_write_line("  state                    - fase, ronda, rol, peer y estado")
	_write_line("  players                  - lista peers, asiento y estado vivo/muerto")
	_write_line("  fps                      - FPS actuales")
	_write_line("  phase <fase>             - fuerza una fase de partida")
	_write_line("  round <numero>           - cambia la ronda local")
	_write_line("  role <rol>               - faithful/heretic/healer/inquisitor")
	_write_line("  ghost                    - convierte al jugador local en fantasma")
	_write_line("  revive                   - revive al jugador local para pruebas")
	_write_line("  nightresult none         - anuncio sin victimas")
	_write_line("  nightresult saved        - anuncio de salvacion del Sacerdote")
	_write_line("  nightresult kill <peer>  - anuncio de muerte de un peer")
	_write_line("  godcamera                - enfoca la camara del dios")
	_write_line("  playercamera             - restaura la camara del jugador/fantasma")
	_write_line("Fases: role_reveal, god_intro, night_start, heretic_action, healer_action,")
	_write_line("       inquisitor_action, night_resolution, day_announcement, day_discussion,")
	_write_line("       voting, sacrifice, match_end")

func _print_state() -> void:
	var peer_id := _local_peer_id()
	var alive := true if peer_id <= 0 else MatchAuthority.is_peer_publicly_alive(peer_id)
	_write_line("phase=%s (%d)" % [_phase_name(GameManager.phase), int(GameManager.phase)])
	_write_line("round=%d  peer=%d  role=%s  alive=%s" % [GameManager.round_number, peer_id, MatchAuthority.role_title(), str(alive)])
	_write_line("host=%s  server=%s  practice=%s" % [str(NetworkManager.is_host), str(multiplayer.is_server()), str(PracticeManager.active)])

func _print_players() -> void:
	if NetworkManager.peers.is_empty():
		_write_line("No hay peers registrados.")
		return
	var peer_ids := NetworkManager.peers.keys()
	peer_ids.sort()
	for raw_peer_id in peer_ids:
		var peer_id := int(raw_peer_id)
		var data: Dictionary = NetworkManager.peers[raw_peer_id]
		var name := str(data.get("display_name", "Acólito %d" % peer_id))
		var seat := int(data.get("seat_id", -1))
		var alive := MatchAuthority.is_peer_publicly_alive(peer_id)
		_write_line("peer=%d  seat=%d  %-20s  %s" % [peer_id, seat, name, "ALIVE" if alive else "DEAD"])

func _command_phase(args: PackedStringArray) -> void:
	if args.is_empty():
		_write_error("Uso: phase <fase>")
		return
	var phase_value := _phase_from_name(args[0])
	if phase_value < 0:
		_write_error("Fase desconocida: %s" % args[0])
		return
	var phase := phase_value as GameManager.MatchPhase
	if multiplayer.multiplayer_peer != null and multiplayer.is_server() and NetworkManager.is_host:
		MatchAuthority.call("_broadcast_phase", phase)
		_write_line("Fase enviada por host: %s" % _phase_name(phase))
	else:
		MatchAuthority.call("_sync_phase", int(phase), GameManager.round_number)
		_write_line("Fase forzada localmente: %s" % _phase_name(phase))

func _command_round(args: PackedStringArray) -> void:
	if args.is_empty() or not args[0].is_valid_int():
		_write_error("Uso: round <numero>")
		return
	GameManager.round_number = maxi(0, int(args[0]))
	_write_line("Ronda = %d" % GameManager.round_number)

func _command_role(args: PackedStringArray) -> void:
	if args.is_empty():
		_write_error("Uso: role faithful|heretic|healer|inquisitor")
		return
	var role_name := args[0].to_lower()
	var role_value := -1
	match role_name:
		"faithful", "fiel":
			role_value = int(PlayerState.Role.FAITHFUL)
		"heretic", "hereje":
			role_value = int(PlayerState.Role.HERETIC)
		"healer", "priest", "sacerdote":
			role_value = int(PlayerState.Role.HEALER)
		"inquisitor", "inquisidor":
			role_value = int(PlayerState.Role.INQUISITOR)
		_:
			_write_error("Rol desconocido: %s" % args[0])
			return
	MatchAuthority.local_role = role_value as PlayerState.Role
	MatchAuthority.private_role_received.emit(role_value)
	_write_line("Rol local de debug = %s" % MatchAuthority.role_title())

func _command_ghost() -> void:
	var peer_id := _local_peer_id()
	if peer_id <= 0:
		_write_error("No hay peer local activo.")
		return
	if MatchAuthority.is_local_ghost():
		_write_line("El jugador local ya es fantasma.")
		return
	MatchAuthority.public_alive_by_peer[peer_id] = false
	var killed: Array[int] = [peer_id]
	MatchAuthority.night_resolution_received.emit(killed)
	_write_line("Ghost mode forzado para peer %d." % peer_id)

func _command_revive() -> void:
	var peer_id := _local_peer_id()
	if peer_id <= 0:
		_write_error("No hay peer local activo.")
		return
	MatchAuthority.public_alive_by_peer[peer_id] = true
	MatchAuthority.rematch_received.emit()
	_write_line("Peer %d revivido para prueba local." % peer_id)

func _command_night_result(args: PackedStringArray) -> void:
	if args.is_empty():
		_write_error("Uso: nightresult none|saved|kill <peer>")
		return
	var killed: Array[int] = []
	var priest_saved := false
	var mode := args[0].to_lower()
	match mode:
		"none":
			pass
		"saved":
			priest_saved = true
		"kill":
			if args.size() < 2 or not args[1].is_valid_int():
				_write_error("Uso: nightresult kill <peer_id>")
				return
			killed.append(int(args[1]))
		_:
			_write_error("Resultado desconocido: %s" % mode)
			return
	_sync_debug_night_report(killed, priest_saved)
	_command_phase(PackedStringArray(["day_announcement"]))
	_write_line("Night result debug aplicado: %s" % mode)

func _sync_debug_night_report(killed: Array[int], priest_saved: bool) -> void:
	var first_night := GameManager.round_number == 1
	if multiplayer.multiplayer_peer != null and multiplayer.is_server() and NetworkManager.is_host:
		MatchAuthority.rpc("_sync_public_night_report", killed, priest_saved, first_night)
	else:
		MatchAuthority.call("_sync_public_night_report", killed, priest_saved, first_night)

func _command_camera(god_camera: bool) -> void:
	var table := _find_table(get_tree().root)
	if table == null:
		_write_error("No encontre la mesa activa.")
		return
	if god_camera:
		table.call("focus_camera_on_god")
		_write_line("Camara del dios activada.")
	else:
		table.call("restore_local_player_camera")
		_write_line("Camara local restaurada.")

func _find_table(node: Node) -> Node:
	if node.has_method("focus_camera_on_god") and node.has_method("restore_local_player_camera"):
		return node
	for child in node.get_children():
		var found := _find_table(child)
		if found != null:
			return found
	return null

func _local_peer_id() -> int:
	return multiplayer.get_unique_id() if multiplayer.multiplayer_peer != null else 0

func _phase_from_name(raw_name: String) -> int:
	var name := raw_name.to_lower().replace("-", "_")
	var phase_value := -1
	match name:
		"role_reveal", "roles":
			phase_value = int(GameManager.MatchPhase.ROLE_REVEAL)
		"god_intro", "god":
			phase_value = int(GameManager.MatchPhase.GOD_INTRO)
		"night_start", "night":
			phase_value = int(GameManager.MatchPhase.NIGHT_START)
		"heretic_action", "heretic":
			phase_value = int(GameManager.MatchPhase.HERETIC_ACTION)
		"healer_action", "healer", "priest":
			phase_value = int(GameManager.MatchPhase.HEALER_ACTION)
		"inquisitor_action", "inquisitor":
			phase_value = int(GameManager.MatchPhase.INQUISITOR_ACTION)
		"night_resolution", "resolution":
			phase_value = int(GameManager.MatchPhase.NIGHT_RESOLUTION)
		"day_announcement", "announcement":
			phase_value = int(GameManager.MatchPhase.DAY_ANNOUNCEMENT)
		"day_discussion", "discussion":
			phase_value = int(GameManager.MatchPhase.DAY_DISCUSSION)
		"voting", "vote":
			phase_value = int(GameManager.MatchPhase.VOTING)
		"sacrifice":
			phase_value = int(GameManager.MatchPhase.SACRIFICE)
		"match_end", "end":
			phase_value = int(GameManager.MatchPhase.MATCH_END)
	return phase_value

func _phase_name(phase: GameManager.MatchPhase) -> String:
	return GameManager.MatchPhase.keys()[int(phase)].to_lower()

func _write_line(text: String) -> void:
	if _output == null:
		return
	_output.append_text(text + "\n")

func _write_error(text: String) -> void:
	_write_line("ERROR: " + text)
