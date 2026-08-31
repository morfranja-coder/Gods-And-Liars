extends Node3D

signal target_selected(peer_id: int)
signal target_focused(peer_id: int)
signal target_cleared

const PLAYER_AVATAR_SCENE := preload("res://scenes/player/player_avatar.tscn")
const SELECTION_MASK := 2
const RAY_LENGTH := 100.0

var selected_peer_id: int = 0
var focused_peer_id: int = 0
var _avatars: Dictionary = {}

@onready var table_camera: TableCameraLook = $Camera3D
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var pause_ui: CanvasLayer = $PauseUI
@onready var leave_confirm_dialog: ConfirmationDialog = %LeaveConfirmDialog

func _ready() -> void:
	_setup_environment()
	_build_placeholder_table()
	_build_seat_markers()
	NetworkManager.peer_joined.connect(_on_roster_changed)
	NetworkManager.peer_left.connect(_on_roster_changed)
	NetworkManager.peer_updated.connect(_on_roster_changed)
	MatchAuthority.night_resolution_received.connect(_on_night_resolution_received)
	MatchAuthority.vote_resolution_received.connect(_on_vote_resolution_received)
	MatchLeaveManager.leave_started.connect(_on_leave_started)
	MatchLeaveManager.leave_rejected.connect(_on_leave_rejected)
	VideoSettings.settings_changed.connect(_apply_video_environment)
	pause_ui.leave_pressed.connect(_on_leave_match_pressed)
	leave_confirm_dialog.confirmed.connect(_on_leave_confirmed)
	_refresh_roster()
	if multiplayer.is_server() and NetworkManager.is_host:
		MatchAuthority.call_deferred("begin_role_reveal")

func _physics_process(_delta: float) -> void:
	if pause_ui.is_open:
		_clear_focused_target()
		return
	_update_center_target()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputBindings.ACTION_PAUSE):
		pause_ui.toggle()
		table_camera.set_look_enabled(not pause_ui.is_open)
		get_viewport().set_input_as_handled()
		return
	if pause_ui.is_open:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_select_from_screen_position(mouse_event.position)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton and event.is_action_pressed(InputBindings.ACTION_SELECT):
		_select_focused_target()
		get_viewport().set_input_as_handled()

func _setup_environment() -> void:
	if world_environment.environment == null:
		world_environment.environment = Environment.new()
	_apply_video_environment()

func _apply_video_environment() -> void:
	VideoSettings.apply_to_environment(world_environment.environment)

func _on_leave_match_pressed() -> void:
	if MatchLeaveManager.leave_pending:
		return
	leave_confirm_dialog.dialog_text = (
		"Sos el host. Se transferirá la autoridad antes de salir. ¿Querés continuar?"
		if NetworkManager.is_host
		else "¿Seguro que querés abandonar esta partida? Tu grupo se conservará."
	)
	leave_confirm_dialog.popup_centered()

func _on_leave_confirmed() -> void:
	if MatchLeaveManager.request_leave_match():
		pause_ui.set_leave_pending(
			true,
			"Transfiriendo host..." if NetworkManager.is_host else "Abandonando partida..."
		)

func _on_leave_started() -> void:
	pause_ui.set_leave_pending(true, "Procesando salida del ritual...")

func _on_leave_rejected(reason: String) -> void:
	pause_ui.show_leave_error(reason)

func _build_placeholder_table() -> void:
	var table := MeshInstance3D.new()
	table.name = "RitualTable"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 3.0
	mesh.bottom_radius = 3.0
	mesh.height = 0.35
	mesh.radial_segments = 32
	table.mesh = mesh
	table.position.y = 0.75
	add_child(table)

	var floor := MeshInstance3D.new()
	floor.name = "Floor"
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(16.0, 13.0)
	floor.mesh = floor_mesh
	add_child(floor)

	var light := DirectionalLight3D.new()
	light.name = "KeyLight"
	light.rotation_degrees = Vector3(-55.0, -25.0, 0.0)
	light.shadow_enabled = true
	add_child(light)

func _build_seat_markers() -> void:
	var seats := Node3D.new()
	seats.name = "Seats"
	add_child(seats)
	for seat_id in range(TableLayout.SEAT_COUNT):
		var marker := Marker3D.new()
		marker.name = "Seat_%02d" % (seat_id + 1)
		marker.transform = TableLayout.seat_transform(seat_id)
		seats.add_child(marker)

func get_seat_marker(seat_id: int) -> Marker3D:
	if not SeatAllocator.is_valid_seat(seat_id):
		return null
	return get_node_or_null("Seats/Seat_%02d" % (seat_id + 1)) as Marker3D

func _refresh_roster(_unused: int = 0) -> void:
	var active_ids: Array[int] = []
	for raw_peer_id in NetworkManager.peers.keys():
		var peer_id := int(raw_peer_id)
		var peer: Dictionary = NetworkManager.peers[raw_peer_id]
		var seat_id := int(peer.get("seat_id", -1))
		if not SeatAllocator.is_valid_seat(seat_id):
			continue
		active_ids.append(peer_id)
		_spawn_or_update_avatar(peer_id, seat_id)
	for raw_id in _avatars.keys():
		var peer_id := int(raw_id)
		if peer_id not in active_ids:
			var avatar: Node = _avatars[peer_id]
			avatar.queue_free()
			_avatars.erase(peer_id)
			if selected_peer_id == peer_id:
				selected_peer_id = 0
			if focused_peer_id == peer_id:
				_clear_focused_target()

func _spawn_or_update_avatar(peer_id: int, seat_id: int) -> void:
	var marker := get_seat_marker(seat_id)
	if marker == null:
		return
	var avatar: Node3D
	if _avatars.has(peer_id):
		avatar = _avatars[peer_id]
	else:
		avatar = PLAYER_AVATAR_SCENE.instantiate()
		avatar.name = "Peer_%s" % peer_id
		avatar.set_meta("peer_id", peer_id)
		add_child(avatar)
		_avatars[peer_id] = avatar
	avatar.global_transform = marker.global_transform
	if avatar is AvatarSlots:
		(avatar as AvatarSlots).set_player_color(PlayerColors.for_seat(seat_id))
	var peer: Dictionary = NetworkManager.peers.get(peer_id, {})
	var label := avatar.get_node_or_null("NameLabel") as Label3D
	if label != null:
		var display_name := str(peer.get("display_name", ""))
		if display_name.is_empty():
			display_name = "Player %s" % peer_id
		label.text = display_name if MatchAuthority.is_peer_publicly_alive(peer_id) else "† %s" % display_name

func _update_center_target() -> void:
	var center := get_viewport().get_visible_rect().size * 0.5
	var peer_id := _peer_id_from_screen_position(center)
	if peer_id == focused_peer_id:
		return
	focused_peer_id = peer_id
	if focused_peer_id > 0:
		target_focused.emit(focused_peer_id)
	else:
		target_cleared.emit()

func _clear_focused_target() -> void:
	if focused_peer_id == 0:
		return
	focused_peer_id = 0
	target_cleared.emit()

func _select_focused_target() -> void:
	if focused_peer_id <= 0:
		return
	_select_peer(focused_peer_id)

func _select_from_screen_position(screen_position: Vector2) -> void:
	var peer_id := _peer_id_from_screen_position(screen_position)
	if peer_id <= 0:
		return
	_select_peer(peer_id)

func _select_peer(peer_id: int) -> void:
	if not NetworkManager.peers.has(peer_id):
		return
	selected_peer_id = peer_id
	target_selected.emit(peer_id)

func _peer_id_from_screen_position(screen_position: Vector2) -> int:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return 0
	var origin := camera.project_ray_origin(screen_position)
	var end := origin + camera.project_ray_normal(screen_position) * RAY_LENGTH
	var query := _make_selection_query(origin, end)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return 0
	var collider := hit.get("collider") as Node
	var peer_id := _peer_id_from_collider(collider)
	if peer_id <= 0 or not NetworkManager.peers.has(peer_id):
		return 0
	return peer_id

func _make_selection_query(origin: Vector3, end: Vector3) -> PhysicsRayQueryParameters3D:
	var query := PhysicsRayQueryParameters3D.create(origin, end, SELECTION_MASK)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	return query

func _peer_id_from_collider(collider: Node) -> int:
	var current := collider
	while current != null and current != self:
		if current.has_meta("peer_id"):
			return int(current.get_meta("peer_id"))
		current = current.get_parent()
	return 0

func _on_roster_changed(peer_id: int) -> void:
	_refresh_roster(peer_id)

func _on_night_resolution_received(_killed_peer_ids: Array[int]) -> void:
	_refresh_roster()

func _on_vote_resolution_received(_sacrificed_peer_id: int, _tied: bool) -> void:
	_refresh_roster()
