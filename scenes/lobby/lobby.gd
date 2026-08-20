extends Control

@onready var status_label: Label = %StatusLabel
@onready var identity_label: Label = %IdentityLabel
@onready var voice_label: Label = %VoiceLabel
@onready var lobby_list: ItemList = %LobbyList
@onready var players_label: Label = %PlayersLabel
@onready var create_button: Button = %CreateButton
@onready var refresh_button: Button = %RefreshButton
@onready var join_button: Button = %JoinButton
@onready var ready_button: Button = %ReadyButton
@onready var start_button: Button = %StartButton
@onready var leave_button: Button = %LeaveButton

var _lobby_ids: Array[int] = []

func _ready() -> void:
	create_button.pressed.connect(_on_create_pressed)
	refresh_button.pressed.connect(_on_refresh_pressed)
	join_button.pressed.connect(_on_join_pressed)
	ready_button.pressed.connect(_on_ready_pressed)
	start_button.pressed.connect(_on_start_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	lobby_list.item_selected.connect(_on_lobby_selected)
	lobby_list.item_activated.connect(_on_lobby_activated)
	NetworkManager.lobby_list_updated.connect(_on_lobby_list_updated)
	NetworkManager.lobby_state_changed.connect(_on_lobby_state_changed)
	NetworkManager.lobby_error.connect(_on_lobby_error)
	NetworkManager.peer_joined.connect(_on_peer_changed)
	NetworkManager.peer_updated.connect(_on_peer_changed)
	NetworkManager.peer_left.connect(_on_peer_changed)
	NetworkManager.lobby_start_requested.connect(_on_lobby_start_requested)
	Steamworks.steam_ready.connect(_refresh_identity)
	Steamworks.steam_unavailable.connect(_on_steam_unavailable)
	VoiceChat.local_talking_changed.connect(_on_local_talking_changed)
	VoiceChat.remote_talking.connect(_on_remote_talking)
	_refresh_identity()
	_refresh_players()
	_update_buttons()

func _refresh_identity() -> void:
	if Steamworks.initialized:
		identity_label.text = "Steam: %s (%s)" % [Steamworks.persona_name, Steamworks.steam_id]
		status_label.text = "Steam listo. Crea un ritual o busca uno existente."
	else:
		identity_label.text = "Steam: no disponible"
		status_label.text = "Abre este proyecto con GodotSteam 4.20 y Steam iniciado."
	_update_buttons()

func _refresh_players() -> void:
	if NetworkManager.peers.is_empty():
		players_label.text = "Jugadores conectados: 0"
		return
	var lines: PackedStringArray = ["Jugadores conectados: %d" % NetworkManager.peers.size()]
	var ids := NetworkManager.peers.keys()
	ids.sort()
	for peer_id in ids:
		var data: Dictionary = NetworkManager.peers[peer_id]
		var name := str(data.get("display_name", ""))
		if name.is_empty():
			name = "Peer %s" % peer_id
		var ready_text := "LISTO" if bool(data.get("ready", false)) else "NO LISTO"
		var host_text := " HOST" if int(peer_id) == 1 else ""
		lines.append("• %s  [peer %s%s] — %s" % [name, peer_id, host_text, ready_text])
	players_label.text = "\n".join(lines)

func _update_buttons() -> void:
	var steam_ok := Steamworks.initialized
	var in_lobby := NetworkManager.lobby_id != 0
	create_button.disabled = not steam_ok or in_lobby
	refresh_button.disabled = not steam_ok or in_lobby
	join_button.disabled = not steam_ok or in_lobby or lobby_list.get_selected_items().is_empty()
	ready_button.disabled = not in_lobby or multiplayer.multiplayer_peer == null
	ready_button.text = "No listo" if NetworkManager.local_peer_ready() else "Listo"
	start_button.visible = NetworkManager.is_host
	start_button.disabled = not NetworkManager.can_host_start()
	leave_button.disabled = not in_lobby

func _on_create_pressed() -> void:
	NetworkManager.host_lobby()

func _on_refresh_pressed() -> void:
	lobby_list.clear()
	_lobby_ids.clear()
	NetworkManager.refresh_lobbies()

func _on_join_pressed() -> void:
	var selected := lobby_list.get_selected_items()
	if selected.is_empty():
		return
	_join_index(selected[0])

func _on_ready_pressed() -> void:
	NetworkManager.request_local_ready(not NetworkManager.local_peer_ready())

func _on_start_pressed() -> void:
	NetworkManager.request_host_start()

func _on_lobby_selected(_index: int) -> void:
	_update_buttons()

func _on_lobby_activated(index: int) -> void:
	_join_index(index)

func _join_index(index: int) -> void:
	if index < 0 or index >= _lobby_ids.size():
		return
	NetworkManager.join_lobby(_lobby_ids[index])

func _on_leave_pressed() -> void:
	NetworkManager.leave_lobby()
	status_label.text = "Saliste del ritual."
	_refresh_players()
	_update_buttons()

func _on_lobby_list_updated(lobbies: Array) -> void:
	lobby_list.clear()
	_lobby_ids.clear()
	for raw_id in lobbies:
		var id := int(raw_id)
		_lobby_ids.append(id)
		lobby_list.add_item(NetworkManager.get_lobby_name(id))
	status_label.text = "Rituales encontrados: %d" % _lobby_ids.size()
	_update_buttons()

func _on_lobby_state_changed(state: StringName) -> void:
	match state:
		&"creating": status_label.text = "Creando ritual..."
		&"searching": status_label.text = "Buscando rituales..."
		&"joining": status_label.text = "Entrando al ritual..."
		&"hosting": status_label.text = "Ritual creado. Lobby ID: %s" % NetworkManager.lobby_id
		&"in_lobby": status_label.text = "Steam lobby unido. Conectando peer..."
		&"connected": status_label.text = "Peer conectado. Sincronizando identidad..."
		&"starting": status_label.text = "Todos listos. El host inició el ritual."
		&"steam_ready": status_label.text = "Steam listo."
	_refresh_players()
	_update_buttons()

func _on_peer_changed(_peer_id: int) -> void:
	_refresh_players()
	_update_buttons()

func _on_lobby_start_requested() -> void:
	status_label.text = "FASE 2 OK: inicio sincronizado por el host."
	_update_buttons()

func _on_local_talking_changed(is_talking: bool) -> void:
	voice_label.text = "Voz: TRANSMITIENDO..." if is_talking else "Voz: mantené V para hablar"

func _on_remote_talking(peer_id: int) -> void:
	var data: Dictionary = NetworkManager.peers.get(peer_id, {})
	var name := str(data.get("display_name", "Peer %s" % peer_id))
	voice_label.text = "Voz: escuchando a %s" % name

func _on_lobby_error(message: String) -> void:
	status_label.text = "ERROR: %s" % message
	_update_buttons()

func _on_steam_unavailable(reason: String) -> void:
	status_label.text = "Steam no disponible: %s" % reason
	_refresh_identity()
