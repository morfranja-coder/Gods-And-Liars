extends Node3D

signal target_selected(peer_id: int)
signal target_focused(peer_id: int)
signal target_cleared
signal local_emote_requested(index: int)
signal local_chat_message_requested(text: String)
signal private_chat_received(peer_id: int, display_name: String, text: String)

const PLAYER_AVATAR_SCENE := preload("res://scenes/player/player_avatar.tscn")
const GHOST_CONTROLLER_SCENE := preload("res://scenes/player/ghost_controller.tscn")
const SELECTION_MASK := 2
const RAY_LENGTH := 100.0
const LOCAL_CAMERA_HEIGHT := 0.95
const SCENARIO_COLLISION_MIN_AXIS := 0.75
const PRIVATE_CHAT_MAX_LENGTH := 220
const REMOTE_GHOST_FOLDER := "res://assets/FantasmaPJ"

var selected_peer_id: int = 0
var focused_peer_id: int = 0
var _avatars: Dictionary = {}
var _local_ghost: GhostController = null
var _ghost_transition_started := false
var _remote_ghost_visuals: Dictionary = {}
var _god_head_tween: Tween = null

@onready var table_camera: TableCameraLook = _ensure_table_camera()
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var player_list_ui: PlayerListUI = $PlayerListUI
@onready var emote_wheel_ui: EmoteWheelUI = $EmoteWheelUI
@onready var chat_ui: ChatUI = $ChatUI
@onready var day_vote_ui: CanvasLayer = $DayVoteUI
@onready var night_action_ui: CanvasLayer = $NightActionUI
@onready var ghost_hud: GhostHUD = $GhostHUD
@onready var pause_ui: CanvasLayer = $PauseUI
@onready var leave_confirm_dialog: ConfirmationDialog = %LeaveConfirmDialog
@onready var living_god_visual: Node3D = $GodState/LivingGod
@onready var dead_god_visual: Node3D = $GodState/DeadGod

func _ready() -> void:
	_setup_environment()
	_ensure_table_center()
	NetworkManager.peer_joined.connect(_on_roster_changed)
	NetworkManager.peer_left.connect(_on_roster_changed)
	NetworkManager.peer_updated.connect(_on_roster_changed)
	MatchAuthority.night_resolution_received.connect(_on_night_resolution_received)
	MatchAuthority.vote_resolution_received.connect(_on_vote_resolution_received)
	MatchAuthority.vote_state_synced.connect(_on_vote_state_synced)
	MatchAuthority.rematch_received.connect(_on_rematch_received)
	MatchAuthority.phase_synced.connect(_on_match_phase_synced_for_input)
	MatchLeaveManager.leave_started.connect(_on_leave_started)
	MatchLeaveManager.leave_rejected.connect(_on_leave_rejected)
	VideoSettings.settings_changed.connect(_apply_video_environment)
	player_list_ui.open_state_changed.connect(_on_player_list_open_state_changed)
	emote_wheel_ui.open_state_changed.connect(_on_emote_wheel_open_state_changed)
	emote_wheel_ui.emote_requested.connect(_on_emote_requested)
	chat_ui.open_state_changed.connect(_on_chat_open_state_changed)
	chat_ui.message_submitted.connect(_on_chat_message_submitted)
	if chat_ui.has_signal("private_message_submitted"):
		chat_ui.connect("private_message_submitted", _on_private_message_submitted)
	pause_ui.leave_pressed.connect(_on_leave_match_pressed)
	leave_confirm_dialog.confirmed.connect(_on_leave_confirmed)
	_refresh_roster()
	_refresh_god_state()
	call_deferred("_ensure_scenario_collisions")
	call_deferred("_ensure_named_environment_collision", "ornate_religious_sculpture_3d_model")
	if multiplayer.is_server() and NetworkManager.is_host:
		MatchAuthority.call_deferred("begin_role_reveal")

func _physics_process(_delta: float) -> void:
	_update_camera_input_state()

	if _gameplay_input_blocked() or _is_ghost_mode_active():
		_clear_focused_target()
		return
	_update_center_target()

func _unhandled_input(event: InputEvent) -> void:
	if _handle_chat_input(event):
		return
	if _handle_pause_input(event):
		return
	if pause_ui.is_open:
		return
	if _handle_social_input(event):
		return
	if player_list_ui.is_open or emote_wheel_ui.is_open:
		return
	_handle_targeting_input(event)

func _handle_chat_input(event: InputEvent) -> bool:
	if chat_ui.is_open:
		if chat_ui.handle_input(event):
			_update_camera_input_state()
			get_viewport().set_input_as_handled()
		return true
	return false

func _handle_pause_input(event: InputEvent) -> bool:
	if not event.is_action_pressed(InputBindings.ACTION_PAUSE):
		return false
	_close_social_overlays()
	pause_ui.toggle()
	_update_camera_input_state()
	get_viewport().set_input_as_handled()
	return true

func _handle_social_input(event: InputEvent) -> bool:
	if _is_ghost_mode_active():
		return false
	if event.is_action_pressed(InputBindings.ACTION_CHAT):
		_close_social_overlays()
		chat_ui.open_for_typing(event is InputEventJoypadButton)
		_update_camera_input_state()
		get_viewport().set_input_as_handled()
		return true
	if emote_wheel_ui.handle_input(event):
		_update_camera_input_state()
		get_viewport().set_input_as_handled()
		return true
	if event.is_action_pressed(InputBindings.ACTION_PLAYER_LIST):
		if emote_wheel_ui.is_open:
			emote_wheel_ui.close()
		player_list_ui.toggle()
		_update_camera_input_state()
		get_viewport().set_input_as_handled()
		return true
	return false

func _handle_targeting_input(event: InputEvent) -> void:
	if GameManager.phase == GameManager.MatchPhase.VOTING or NightPhaseRules.is_action_phase(GameManager.phase):
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

func _ensure_table_camera() -> TableCameraLook:
	var existing := get_node_or_null("Camera3D")
	if existing is TableCameraLook:
		return existing as TableCameraLook
	var camera := TableCameraLook.new()
	camera.name = "LocalPlayerCamera"
	camera.fov = 72.0
	camera.near = 0.05
	add_child(camera)
	return camera



func focus_camera_on_god() -> void:
	if _is_ghost_mode_active():
		return

	var god_camera := _get_manual_god_camera()
	if god_camera == null:
		push_warning("No se encontro una Camera3D llamada CamaraDios ni una Camera3D dentro de CamaraDios.")
		return

	table_camera.set_look_enabled(false)
	table_camera.current = false
	god_camera.current = true
	_play_god_head_motion()


func _get_manual_god_camera() -> Camera3D:
	# Nombre exacto creado manualmente en la escena.
	var camera_node := find_child("CameraDios", true, false)

	if camera_node is Camera3D:
		return camera_node as Camera3D

	if camera_node != null:
		var cameras := camera_node.find_children("*", "Camera3D", true, false)
		if not cameras.is_empty():
			return cameras[0] as Camera3D

	push_warning("No se encontro CameraDios en la escena.")
	return null


func _play_god_head_motion() -> void:
	var god: Node3D = living_god_visual

	if MatchAuthority.is_local_ghost():
		god = dead_god_visual

	if god == null:
		return

	var skeleton: Skeleton3D = _find_god_head_skeleton(god)

	if skeleton == null:
		return

	var bone_index: int = _find_god_head_bone(skeleton)

	if bone_index < 0:
		return

	if _god_head_tween != null:
		_god_head_tween.kill()

	var base_rotation: Quaternion = skeleton.get_bone_pose_rotation(bone_index)

	var first_rotation: Quaternion = (
		Quaternion(Vector3.UP, deg_to_rad(4.0))
		* Quaternion(Vector3.RIGHT, deg_to_rad(-2.0))
		* base_rotation
	)

	var second_rotation: Quaternion = (
		Quaternion(Vector3.UP, deg_to_rad(-3.0))
		* Quaternion(Vector3.RIGHT, deg_to_rad(1.5))
		* base_rotation
	)

	_god_head_tween = create_tween()

	_god_head_tween.tween_method(
		func(value: Quaternion) -> void:
			skeleton.set_bone_pose_rotation(bone_index, value),
		base_rotation,
		first_rotation,
		0.75
	)

	_god_head_tween.tween_method(
		func(value: Quaternion) -> void:
			skeleton.set_bone_pose_rotation(bone_index, value),
		first_rotation,
		second_rotation,
		0.90
	)

	_god_head_tween.tween_method(
		func(value: Quaternion) -> void:
			skeleton.set_bone_pose_rotation(bone_index, value),
		second_rotation,
		base_rotation,
		0.75
	)


func _find_god_head_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		var skeleton: Skeleton3D = node as Skeleton3D

		if _find_god_head_bone(skeleton) >= 0:
			return skeleton

	for child in node.get_children():
		var found: Skeleton3D = _find_god_head_skeleton(child)

		if found != null:
			return found

	return null


func _find_god_head_bone(skeleton: Skeleton3D) -> int:
	var fallback: int = -1

	for bone_index in range(skeleton.get_bone_count()):
		var bone_name: String = str(
			skeleton.get_bone_name(bone_index)
		).to_lower()

		if bone_name.contains("head") or bone_name.contains("cabeza"):
			return bone_index

		if (
			fallback < 0
			and (
				bone_name.contains("neck")
				or bone_name.contains("cuello")
			)
		):
			fallback = bone_index

	return fallback



func restore_local_player_camera() -> void:
	if _is_ghost_mode_active():
		if _local_ghost != null:
			_local_ghost.restore_camera()

		return

	var god_camera: Camera3D = (
		_get_manual_god_camera()
	)

	if god_camera != null:
		god_camera.current = false

	var local_peer_id: int = (
		multiplayer.get_unique_id()
		if multiplayer.multiplayer_peer != null
		else 0
	)

	var avatar: Node3D = (
		_avatars.get(local_peer_id)
		as Node3D
	)

	if avatar == null:
		return

	_setup_local_player_view(avatar)

	table_camera.current = true

	_update_camera_input_state()

func _setup_environment() -> void:
	if world_environment.environment == null:
		world_environment.environment = Environment.new()
	_apply_video_environment()

func _apply_video_environment() -> void:
	VideoSettings.apply_to_environment(world_environment.environment)

func _on_player_list_open_state_changed(_is_open: bool) -> void:
	_update_camera_input_state()

func _on_emote_wheel_open_state_changed(_is_open: bool) -> void:
	_update_camera_input_state()

func _on_chat_open_state_changed(_is_open: bool) -> void:
	_update_camera_input_state()

func _on_emote_requested(index: int) -> void:
	var local_peer_id := multiplayer.get_unique_id()
	var local_avatar := _avatars.get(local_peer_id) as AvatarSlots
	if local_avatar != null and not MatchAuthority.is_local_ghost():
		local_avatar.play_movement(index)
	local_emote_requested.emit(index)

func _on_chat_message_submitted(text: String) -> void:
	if MatchAuthority.is_local_ghost():
		return
	local_chat_message_requested.emit(text)

func _on_private_message_submitted(target_peer_id: int, text: String) -> void:
	send_private_chat(target_peer_id, text)

func send_private_chat(target_peer_id: int, text: String) -> void:
	if MatchAuthority.is_local_ghost() or multiplayer.multiplayer_peer == null:
		return
	var local_peer_id := multiplayer.get_unique_id()
	if not _can_private_chat(local_peer_id, target_peer_id):
		return
	var clean_text := text.strip_edges().left(PRIVATE_CHAT_MAX_LENGTH)
	if clean_text.is_empty():
		return
	if multiplayer.is_server():
		_server_route_private_chat(local_peer_id, target_peer_id, clean_text)
	else:
		_request_private_chat.rpc_id(1, target_peer_id, clean_text)

func _server_route_private_chat(sender_peer_id: int, target_peer_id: int, text: String) -> void:
	if not multiplayer.is_server() or not _can_private_chat(sender_peer_id, target_peer_id):
		return
	var clean_text := text.strip_edges().left(PRIVATE_CHAT_MAX_LENGTH)
	if clean_text.is_empty():
		return
	var sender_data: Dictionary = NetworkManager.peers.get(sender_peer_id, {})
	var sender_name := str(sender_data.get("display_name", "Acólito %d" % sender_peer_id))
	if target_peer_id == multiplayer.get_unique_id():
		_receive_private_chat(sender_peer_id, sender_name, clean_text)
	elif not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		_receive_private_chat.rpc_id(target_peer_id, sender_peer_id, sender_name, clean_text)

func _can_private_chat(sender_peer_id: int, target_peer_id: int) -> bool:
	if sender_peer_id <= 0 or target_peer_id <= 0 or sender_peer_id == target_peer_id:
		return false
	if not NetworkManager.peers.has(sender_peer_id) or not NetworkManager.peers.has(target_peer_id):
		return false
	return (
		MatchAuthority.is_peer_publicly_alive(sender_peer_id)
		and MatchAuthority.is_peer_publicly_alive(target_peer_id)
	)

func _close_social_overlays() -> void:
	if player_list_ui.is_open:
		player_list_ui.close()
	if emote_wheel_ui.is_open:
		emote_wheel_ui.close()
	if chat_ui.is_open:
		chat_ui.close()

func _gameplay_input_blocked() -> bool:
	var vote_blocks_input := false
	if day_vote_ui != null and day_vote_ui.has_method("blocks_gameplay_input"):
		vote_blocks_input = bool(day_vote_ui.call("blocks_gameplay_input"))

	var night_blocks_input := false
	if night_action_ui != null and night_action_ui.has_method("blocks_gameplay_input"):
		night_blocks_input = bool(night_action_ui.call("blocks_gameplay_input"))

	return (
		pause_ui.is_open
		or player_list_ui.is_open
		or emote_wheel_ui.is_open
		or chat_ui.is_open
		or vote_blocks_input
		or night_blocks_input
	)

func _update_camera_input_state() -> void:
	var gameplay_enabled := not _gameplay_input_blocked()
	table_camera.set_look_enabled(gameplay_enabled and not _is_ghost_mode_active())

	if gameplay_enabled:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if _local_ghost != null:
		_local_ghost.set_input_enabled(gameplay_enabled)


func _on_match_phase_synced_for_input(_phase: int) -> void:
	call_deferred("_update_camera_input_state")

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

func _ensure_table_center() -> Marker3D:
	var existing := get_node_or_null("TableCenter") as Marker3D
	if existing != null:
		return existing
	var center := Marker3D.new()
	center.name = "TableCenter"
	add_child(center)
	var summed_position := Vector3.ZERO
	var valid_seats := 0
	for seat_id in range(TableLayout.SEAT_COUNT):
		var seat := get_seat_marker(seat_id)
		if seat == null:
			continue
		summed_position += seat.global_position
		valid_seats += 1
	if valid_seats > 0:
		center.global_position = summed_position / float(valid_seats)
	return center

func get_table_center() -> Marker3D:
	return get_node_or_null("TableCenter") as Marker3D

func _seat_facing_transform(marker: Marker3D) -> Transform3D:
	var center := get_table_center()
	if center == null:
		return marker.global_transform
	var origin := marker.global_position
	var target := center.global_position
	target.y = origin.y
	if origin.distance_squared_to(target) <= 0.000001:
		return marker.global_transform
	var facing := Transform3D(Basis.IDENTITY, origin).looking_at(target, Vector3.UP, true)
	facing.basis = facing.basis.scaled(marker.global_transform.basis.get_scale())
	return facing

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
	_refresh_remote_ghost_visuals()

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
	avatar.global_transform = _seat_facing_transform(marker)

	_ensure_vote_turn_effect_anchor(
		avatar,
		peer_id
	)
	if avatar is AvatarSlots:
		(avatar as AvatarSlots).set_player_color(PlayerColors.for_seat(seat_id))
	if peer_id == multiplayer.get_unique_id():
		_setup_local_player_view(avatar)
	var peer: Dictionary = NetworkManager.peers.get(peer_id, {})
	var label := avatar.get_node_or_null("NameLabel") as Label3D
	if label != null:
		var display_name := str(peer.get("display_name", ""))
		if display_name.is_empty():
			display_name = "Acólito %s" % peer_id
		label.text = display_name
		label.visible = MatchAuthority.is_peer_publicly_alive(peer_id) and peer_id != multiplayer.get_unique_id()

func _ensure_vote_turn_effect_anchor(
	avatar: Node3D,
	peer_id: int
) -> Marker3D:
	var existing := (
		avatar.get_node_or_null(
			"VoteTurnEffectAnchor"
		)
		as Marker3D
	)

	if existing != null:
		return existing

	var vote_marker := Marker3D.new()

	vote_marker.name = "VoteTurnEffectAnchor"

	vote_marker.position = Vector3(
		0.0,
		1.75,
		0.0
	)

	# Invisible por ahora.
	# Este es el punto donde luego se monta el efecto.
	vote_marker.visible = false

	vote_marker.set_meta(
		"peer_id",
		peer_id
	)

	vote_marker.set_meta(
		"vote_turn_active",
		false
	)

	avatar.add_child(vote_marker)

	return vote_marker


func _on_vote_state_synced(
	_votes: Dictionary,
	current_voter_peer_id: int
) -> void:
	for raw_peer_id in _avatars.keys():
		var peer_id: int = int(raw_peer_id)

		var avatar: Node3D = (
			_avatars[raw_peer_id]
			as Node3D
		)

		if avatar == null:
			continue

		var vote_marker: Marker3D = (
			_ensure_vote_turn_effect_anchor(
				avatar,
				peer_id
			)
		)

		vote_marker.set_meta(
			"vote_turn_active",
			peer_id == current_voter_peer_id
		)

		vote_marker.set_meta(
			"current_voter_peer_id",
			current_voter_peer_id
		)


func _setup_local_player_view(avatar: Node3D) -> void:
	var center := get_table_center()
	if center == null:
		return
	var camera_position := avatar.global_position + Vector3.UP * LOCAL_CAMERA_HEIGHT
	var camera_target := center.global_position
	camera_target.y = camera_position.y
	if camera_position.distance_squared_to(camera_target) <= 0.000001:
		return
	var camera_transform := Transform3D(Basis.IDENTITY, camera_position).looking_at(
		camera_target,
		Vector3.UP,
	)
	table_camera.anchor_to(camera_transform)
	table_camera.current = true
	if avatar is AvatarSlots:
		(avatar as AvatarSlots).set_local_perspective(true)

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


func _ensure_named_environment_collision(target_name: String) -> void:
	var target := _find_node_name_recursive(self, target_name.to_lower())

	if target == null:
		push_warning("No se encontro objeto para colision: %s" % target_name)
		return

	_add_scenario_collisions_recursive(target)


func _find_node_name_recursive(node: Node, target_name: String) -> Node:
	var current_name := str(node.name).to_lower()

	if current_name.contains(target_name):
		return node

	for child in node.get_children():
		var found := _find_node_name_recursive(child, target_name)
		if found != null:
			return found

	return null



func _ensure_scenario_collisions() -> void:
	var scenario_root := _find_scenario_root()
	if scenario_root == null:
		return
	_add_scenario_collisions_recursive(scenario_root)

func _find_scenario_root() -> Node3D:
	for child in get_children():
		if child is Node3D and str(child.name).begins_with("EscenarioAlfa"):
			return child as Node3D
	return null

func _add_scenario_collisions_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		_ensure_mesh_collision(node as MeshInstance3D)
	for child in node.get_children():
		_add_scenario_collisions_recursive(child)

func _ensure_mesh_collision(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance.mesh == null or not mesh_instance.visible:
		return
	for child in mesh_instance.get_children():
		if child is StaticBody3D:
			return
	var size := mesh_instance.get_aabb().size
	var scale := mesh_instance.global_basis.get_scale()
	var scaled_size := Vector3(absf(size.x * scale.x), absf(size.y * scale.y), absf(size.z * scale.z))
	var largest_axis := maxf(scaled_size.x, maxf(scaled_size.y, scaled_size.z))
	if largest_axis < SCENARIO_COLLISION_MIN_AXIS:
		return
	mesh_instance.create_trimesh_collision()
	for child in mesh_instance.get_children():
		if child is StaticBody3D:
			var body := child as StaticBody3D
			body.collision_layer = 1
			body.collision_mask = 0

func _on_roster_changed(peer_id: int) -> void:
	_refresh_roster(peer_id)

func _on_night_resolution_received(_killed_peer_ids: Array[int]) -> void:
	_refresh_roster()
	_refresh_god_state()
	_begin_local_ghost_transition()
	_refresh_remote_ghost_visuals()

func _on_vote_resolution_received(_sacrificed_peer_id: int, _tied: bool) -> void:
	_refresh_roster()
	_refresh_god_state()
	_begin_local_ghost_transition()
	_refresh_remote_ghost_visuals()

func _refresh_god_state() -> void:
	var local_peer_id := multiplayer.get_unique_id()
	var local_is_dead := (
		NetworkManager.peers.has(local_peer_id)
		and not MatchAuthority.is_peer_publicly_alive(local_peer_id)
	)
	living_god_visual.visible = not local_is_dead
	dead_god_visual.visible = local_is_dead

func _begin_local_ghost_transition() -> void:
	if _ghost_transition_started or not MatchAuthority.is_local_ghost():
		return
	_ghost_transition_started = true
	var local_peer_id := multiplayer.get_unique_id()
	var avatar := _avatars.get(local_peer_id) as AvatarSlots
	var spawn_transform := Transform3D.IDENTITY
	if avatar != null:
		spawn_transform = avatar.global_transform
		await avatar.play_death_and_hide()
	_spawn_local_ghost(spawn_transform)
	_refresh_remote_ghost_visuals()

func _spawn_local_ghost(spawn_transform: Transform3D) -> void:
	_local_ghost = GHOST_CONTROLLER_SCENE.instantiate() as GhostController
	_local_ghost.name = "LocalGhost"
	add_child(_local_ghost)
	_local_ghost.global_transform = spawn_transform
	var is_heretic := MatchAuthority.local_role == PlayerState.Role.HERETIC
	_local_ghost.activate(is_heretic)
	ghost_hud.show_ghost_mode(is_heretic)
	table_camera.current = false
	_close_social_overlays()
	_update_camera_input_state()

func _refresh_remote_ghost_visuals() -> void:
	if not MatchAuthority.is_local_ghost():
		_clear_remote_ghost_visuals()
		return
	var local_peer_id := multiplayer.get_unique_id() if multiplayer.multiplayer_peer != null else 0
	for raw_peer_id in NetworkManager.peers.keys():
		var peer_id := int(raw_peer_id)
		if peer_id == local_peer_id or MatchAuthority.is_peer_publicly_alive(peer_id):
			_remove_remote_ghost_visual(peer_id)
			continue
		if _remote_ghost_visuals.has(peer_id):
			continue
		var avatar := _avatars.get(peer_id) as Node3D
		if avatar == null:
			continue
		var visual := _create_remote_ghost_visual(peer_id)
		add_child(visual)
		visual.global_transform = avatar.global_transform
		_remote_ghost_visuals[peer_id] = visual

func _create_remote_ghost_visual(peer_id: int) -> Node3D:
	var root := Node3D.new()
	root.name = "RemoteGhost_%d" % peer_id
	var ghost_scene := _load_first_glb_from_folder(REMOTE_GHOST_FOLDER)
	if ghost_scene != null:
		root.add_child(ghost_scene.instantiate())
		return root
	var fallback := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.35
	mesh.height = 1.4
	fallback.mesh = mesh
	fallback.position.y = 0.7
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.72, 0.82, 0.9, 0.28)
	fallback.material_override = material
	root.add_child(fallback)
	return root

func _load_first_glb_from_folder(folder_path: String) -> PackedScene:
	var directory := DirAccess.open(folder_path)
	if directory == null:
		return null
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.get_extension().to_lower() == "glb":
			var resource := ResourceLoader.load(folder_path.path_join(file_name))
			directory.list_dir_end()
			return resource as PackedScene
		file_name = directory.get_next()
	directory.list_dir_end()
	return null

func _remove_remote_ghost_visual(peer_id: int) -> void:
	if not _remote_ghost_visuals.has(peer_id):
		return
	var visual := _remote_ghost_visuals[peer_id] as Node
	if is_instance_valid(visual):
		visual.queue_free()
	_remote_ghost_visuals.erase(peer_id)

func _clear_remote_ghost_visuals() -> void:
	for raw_peer_id in _remote_ghost_visuals.keys():
		_remove_remote_ghost_visual(int(raw_peer_id))

func _is_ghost_mode_active() -> bool:
	return _local_ghost != null

func _on_rematch_received() -> void:
	_ghost_transition_started = false
	if _local_ghost != null:
		_local_ghost.queue_free()
		_local_ghost = null
	_clear_remote_ghost_visuals()
	for avatar in _avatars.values():
		(avatar as Node3D).visible = true
	ghost_hud.hide_ghost_mode()
	table_camera.current = true
	_refresh_god_state()
	_update_camera_input_state()

@rpc("any_peer", "reliable")
func _request_private_chat(target_peer_id: int, text: String) -> void:
	if not multiplayer.is_server():
		return
	_server_route_private_chat(multiplayer.get_remote_sender_id(), target_peer_id, text)

@rpc("authority", "call_remote", "reliable")
func _receive_private_chat(sender_peer_id: int, sender_name: String, text: String) -> void:
	if MatchAuthority.is_local_ghost():
		return
	private_chat_received.emit(sender_peer_id, sender_name, text)
