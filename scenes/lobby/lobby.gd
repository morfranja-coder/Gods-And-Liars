extends Control

const TABLE_SCENE := "res://scenes/table/table.tscn"
const SETTINGS_SCENE := "res://scenes/settings/settings_menu.tscn"
const DIAGNOSTICS_REFRESH_SECONDS := 0.5

var _invite_when_party_ready: bool = false
var _diagnostics_elapsed: float = 0.0

@onready var status_label: Label = %StatusLabel
@onready var identity_label: Label = %IdentityLabel
@onready var voice_label: Label = %VoiceLabel
@onready var diagnostics_label: Label = %DiagnosticsLabel
@onready var party_label: Label = %PartyLabel
@onready var players_label: Label = %PlayersLabel
@onready var invite_button: Button = %InviteButton
@onready var quick_match_button: Button = %QuickMatchButton
@onready var cancel_search_button: Button = %CancelSearchButton
@onready var ready_button: Button = %ReadyButton
@onready var start_button: Button = %StartButton
@onready var leave_match_button: Button = %LeaveMatchButton
@onready var leave_party_button: Button = %LeavePartyButton
@onready var options_button: Button = %OptionsButton
@onready var leave_match_confirm_dialog: ConfirmationDialog = %LeaveMatchConfirmDialog

func _ready() -> void:
	invite_button.pressed.connect(_on_invite_pressed)
	quick_match_button.pressed.connect(_on_quick_match_pressed)
	cancel_search_button.pressed.connect(_on_cancel_search_pressed)
	ready_button.pressed.connect(_on_ready_pressed)
	start_button.pressed.connect(_on_start_pressed)
	leave_match_button.pressed.connect(_on_leave_match_pressed)
	leave_match_confirm_dialog.confirmed.connect(_on_leave_match_confirmed)
	leave_party_button.pressed.connect(_on_leave_party_pressed)
	options_button.pressed.connect(_on_options_pressed)
	PartyManager.party_changed.connect(_on_party_changed)
	PartyManager.party_error.connect(_on_party_error)
	PartyManager.party_lobby_state_changed.connect(_on_party_lobby_state_changed)
	MatchmakingManager.queue_state_changed.connect(_on_queue_state_changed)
	MatchmakingManager.search_scope_changed.connect(_on_search_scope_changed)
	MatchmakingManager.queue_error.connect(_on_queue_error)
	NetworkManager.lobby_state_changed.connect(_on_lobby_state_changed)
	NetworkManager.lobby_error.connect(_on_lobby_error)
	NetworkManager.peer_joined.connect(_on_peer_changed)
	NetworkManager.peer_updated.connect(_on_peer_changed)
	NetworkManager.peer_left.connect(_on_peer_changed)
	NetworkManager.lobby_start_requested.connect(_on_lobby_start_requested)
	MatchLeaveManager.leave_started.connect(_on_match_leave_started)
	MatchLeaveManager.leave_rejected.connect(_on_match_leave_rejected)
	Steamworks.steam_ready.connect(_refresh_identity)
	Steamworks.steam_unavailable.connect(_on_steam_unavailable)
	VoiceChat.local_talking_changed.connect(_on_local_talking_changed)
	VoiceChat.remote_talking.connect(_on_remote_talking)
	diagnostics_label.visible = OS.is_debug_build()
	_refresh_identity()
	_refresh_party()
	_refresh_players()
	_refresh_queue_status()
	_refresh_diagnostics()
	_update_buttons()
	_show_pending_leave_feedback()

func _process(delta: float) -> void:
	if not diagnostics_label.visible:
		return
	_diagnostics_elapsed += delta
	if _diagnostics_elapsed < DIAGNOSTICS_REFRESH_SECONDS:
		return
	_diagnostics_elapsed = 0.0
	_refresh_diagnostics()

func _show_pending_leave_feedback() -> void:
	var message := MatchLeaveManager.consume_last_leave_message()
	if not message.is_empty():
		status_label.text = message
		return
	var error_message := MatchLeaveManager.consume_last_leave_error()
	if not error_message.is_empty():
		status_label.text = error_message

func _refresh_identity() -> void:
	if Steamworks.initialized:
		identity_label.text = "Steam: %s (%s)" % [Steamworks.persona_name, Steamworks.steam_id]
		if MatchmakingManager.state == MatchmakingManager.STATE_IDLE and NetworkManager.lobby_id == 0:
			status_label.text = "Armá tu grupo o buscá una partida rápida."
	else:
		identity_label.text = "Steam: no disponible"
		status_label.text = "Abrí este build con Steam iniciado."
	_refresh_diagnostics()
	_update_buttons()

func _refresh_party() -> void:
	var lines: PackedStringArray = ["TU GRUPO — %d/8" % PartyManager.size()]
	var ids := PartyManager.member_ids()
	for steam_id in ids:
		var display_name := str(PartyManager.state.members.get(steam_id, "Steam %s" % steam_id))
		var leader_text := "  ★ LÍDER" if steam_id == PartyManager.state.leader_steam_id else ""
		lines.append("• %s%s" % [display_name, leader_text])
	party_label.text = "\n".join(lines)
	_refresh_diagnostics()

func _refresh_players() -> void:
	if NetworkManager.peers.is_empty():
		players_label.text = "PARTIDA — 0/8\nEsperando Match..."
		_refresh_diagnostics()
		return
	var lines: PackedStringArray = ["PARTIDA — %d/8" % NetworkManager.peers.size()]
	var ids := NetworkManager.peers.keys()
	ids.sort()
	for peer_id in ids:
		var data: Dictionary = NetworkManager.peers[peer_id]
		var display_name := str(data.get("display_name", ""))
		if display_name.is_empty():
			display_name = "Peer %s" % peer_id
		var ready_text := "LISTO" if bool(data.get("ready", false)) else "NO LISTO"
		var host_text := " HOST" if int(peer_id) == 1 else ""
		var seat_id := int(data.get("seat_id", -1))
		var seat_text := "S%02d" % (seat_id + 1) if SeatAllocator.is_valid_seat(seat_id) else "SIN ASIENTO"
		lines.append("• %s  [%s%s / %s] — %s" % [display_name, peer_id, host_text, seat_text, ready_text])
	players_label.text = "\n".join(lines)
	_refresh_diagnostics()

func _refresh_queue_status() -> void:
	match MatchmakingManager.state:
		MatchmakingManager.STATE_SEARCHING:
			status_label.text = (
				"Buscando partida... grupo %d/8 · faltan %d · alcance %s"
				% [PartyManager.size(), MatchmakingManager.slots_needed(), MatchmakingManager.search_scope_name()]
			)
		MatchmakingManager.STATE_RESERVING:
			status_label.text = "Partida compatible encontrada. Reservando lugar para todo el grupo..."
		MatchmakingManager.STATE_HOSTING:
			status_label.text = "No había una partida compatible. Creando una para completar 8/8..."
		MatchmakingManager.STATE_ANCHORING:
			status_label.text = "Match creado. Buscando anchors compatibles para converger..."
		MatchmakingManager.STATE_MATCH_FOUND:
			status_label.text = "Partida encontrada. Reuniendo jugadores..."
		_:
			if Steamworks.initialized and NetworkManager.lobby_id == 0:
				status_label.text = "Armá tu grupo o buscá una partida rápida."
	_refresh_diagnostics()

func _refresh_diagnostics() -> void:
	if not is_instance_valid(diagnostics_label) or not diagnostics_label.visible:
		return
	var steam_id: int = Steamworks.steam_id if Steamworks.initialized else 0
	var party_lobby_id: int = PartyManager.party_lobby_id
	var target_lobby_id: int = PartyManager.match_target_lobby_id
	var match_lobby_id: int = NetworkManager.lobby_id
	var peer_count: int = NetworkManager.peers.size()
	var open_slots: int = NetworkManager.advertised_open_slots() if NetworkManager.is_host else -1
	var host_text := "yes" if NetworkManager.is_host else "no"
	var started_text := "yes" if NetworkManager.lobby_started else "no"
	var slots_text := str(open_slots) if open_slots >= 0 else "remote"
	diagnostics_label.text = (
		"DEV NET · steam=%d · party=%d · target=%d · match=%d · queue=%s · scope=%s · peers=%d/8 · open=%s · host=%s · started=%s"
		% [
			steam_id,
			party_lobby_id,
			target_lobby_id,
			match_lobby_id,
			str(MatchmakingManager.state),
			MatchmakingManager.search_scope_name(),
			peer_count,
			slots_text,
			host_text,
			started_text,
		]
	)

func _update_buttons() -> void:
	var steam_ok := Steamworks.initialized
	var in_match := NetworkManager.lobby_id != 0
	var searching := MatchmakingManager.state != MatchmakingManager.STATE_IDLE
	var started := NetworkManager.lobby_started
	invite_button.disabled = not steam_ok or in_match or PartyManager.size() >= QuickMatchRules.TARGET_PLAYERS
	quick_match_button.disabled = not steam_ok or in_match or searching or not PartyManager.can_queue()
	cancel_search_button.visible = searching and not in_match
	cancel_search_button.disabled = not PartyManager.is_local_leader()
	ready_button.visible = in_match and not started
	ready_button.disabled = not in_match or multiplayer.multiplayer_peer == null
	ready_button.text = "No listo" if NetworkManager.local_peer_ready() else "Listo"
	start_button.visible = in_match and NetworkManager.is_host and not started
	start_button.disabled = not NetworkManager.can_host_start()
	leave_match_button.visible = in_match and not started
	leave_match_button.disabled = MatchLeaveManager.leave_pending
	leave_party_button.visible = PartyManager.party_lobby_id != 0 and not in_match and not searching
	options_button.disabled = searching

func _on_invite_pressed() -> void:
	if PartyManager.party_lobby_id == 0:
		_invite_when_party_ready = true
		PartyManager.ensure_party_lobby()
		status_label.text = "Preparando grupo de Steam..."
		return
	PartyManager.open_invite_overlay()

func _on_quick_match_pressed() -> void:
	if MatchmakingManager.start_party_quick_match():
		_refresh_queue_status()
	_update_buttons()

func _on_cancel_search_pressed() -> void:
	MatchmakingManager.cancel_quick_match()
	_refresh_queue_status()
	_update_buttons()

func _on_ready_pressed() -> void:
	NetworkManager.request_local_ready(not NetworkManager.local_peer_ready())

func _on_start_pressed() -> void:
	NetworkManager.request_host_start()

func _on_options_pressed() -> void:
	get_tree().change_scene_to_file(SETTINGS_SCENE)

func _on_leave_match_pressed() -> void:
	if NetworkManager.lobby_id == 0 or MatchLeaveManager.leave_pending:
		return
	leave_match_confirm_dialog.dialog_text = (
		"¿Seguro que querés salir de este Match Lobby? Tu grupo se conservará."
		if not NetworkManager.lobby_started
		else "¿Seguro que querés abandonar esta partida?"
	)
	leave_match_confirm_dialog.popup_centered()

func _on_leave_match_confirmed() -> void:
	if NetworkManager.lobby_id == 0:
		return
	if NetworkManager.lobby_started:
		MatchLeaveManager.request_leave_match()
		return
	NetworkManager.leave_lobby()
	MatchmakingManager.reset()
	GameManager.reset_match()
	status_label.text = "Saliste de la partida. Tu grupo se mantiene."
	_refresh_players()
	_update_buttons()

func _on_match_leave_started() -> void:
	leave_match_button.disabled = true
	status_label.text = (
		"Transfiriendo host antes de salir..."
		if NetworkManager.is_host
		else "Abandonando partida..."
	)

func _on_match_leave_rejected(reason: String) -> void:
	status_label.text = reason
	_update_buttons()

func _on_leave_party_pressed() -> void:
	PartyManager.leave_party()
	status_label.text = "Volviste a jugar solo."
	_refresh_party()
	_update_buttons()

func _on_party_changed() -> void:
	_refresh_party()
	_update_buttons()

func _on_party_error(message: String) -> void:
	status_label.text = "GRUPO: %s" % message
	_update_buttons()

func _on_party_lobby_state_changed(state_name: StringName) -> void:
	if state_name == &"ready" and _invite_when_party_ready:
		_invite_when_party_ready = false
		PartyManager.open_invite_overlay()
	elif state_name == &"creating":
		status_label.text = "Preparando grupo de Steam..."
	_refresh_party()
	_update_buttons()

func _on_queue_state_changed(_state_name: StringName) -> void:
	_refresh_queue_status()
	_update_buttons()

func _on_search_scope_changed(_distance_tier: int) -> void:
	_refresh_queue_status()

func _on_queue_error(message: String) -> void:
	status_label.text = "MATCHMAKING: %s" % message
	_update_buttons()

func _on_lobby_state_changed(state_name: StringName) -> void:
	match state_name:
		&"creating": status_label.text = "Preparando Match Lobby..."
		&"joining": status_label.text = "Entrando a la partida encontrada..."
		&"hosting": status_label.text = "Match creado. Esperando completar 8/8..."
		&"in_lobby": status_label.text = "Match unido. Conectando con el host..."
		&"connected": status_label.text = "Conectado. Sincronizando grupo y asientos..."
		&"starting": status_label.text = "8/8 listos. Comienza el ritual."
		&"host_disconnected": status_label.text = "El host abandonó la partida. Volviste con tu grupo."
		&"connection_failed": status_label.text = "No se pudo reservar esa partida. Buscando otra..."
	_refresh_players()
	_update_buttons()

func _on_peer_changed(_peer_id: int) -> void:
	_refresh_players()
	_update_buttons()

func _on_lobby_start_requested() -> void:
	status_label.text = "Inicio sincronizado. Entrando a la mesa..."
	_update_buttons()
	call_deferred("_enter_table")

func _enter_table() -> void:
	get_tree().change_scene_to_file(TABLE_SCENE)

func _on_local_talking_changed(is_talking: bool) -> void:
	voice_label.text = "Voz: TRANSMITIENDO..." if is_talking else "Voz: mantené V para hablar"

func _on_remote_talking(peer_id: int) -> void:
	var data: Dictionary = NetworkManager.peers.get(peer_id, {})
	var display_name := str(data.get("display_name", "Peer %s" % peer_id))
	voice_label.text = "Voz: escuchando a %s" % display_name

func _on_lobby_error(message: String) -> void:
	status_label.text = "ERROR: %s" % message
	_update_buttons()

func _on_steam_unavailable(reason: String) -> void:
	status_label.text = "Steam no disponible: %s" % reason
	_refresh_identity()
