extends Node3D

signal target_selected(peer_id: int)

const PLAYER_AVATAR_SCENE := preload("res://scenes/player/player_avatar.tscn")
const SELECTION_MASK := 2
const RAY_LENGTH := 100.0

var selected_peer_id: int = 0
var _avatars: Dictionary = {}

func _ready() -> void:
	_build_placeholder_table()
	_build_seat_markers()
	NetworkManager.peer_joined.connect(_on_roster_changed)
	NetworkManager.peer_left.connect(_on_roster_changed)
	NetworkManager.peer_updated.connect(_on_roster_changed)
	_refresh_roster()
	if multiplayer.is_server() and NetworkManager.is_host:
		MatchAuthority.call_deferred("begin_role_reveal")

func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	_select_from_screen_position(mouse_event.position)

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
	var peer: Dictionary = NetworkManager.peers.get(peer_id, {})
	var label := avatar.get_node_or_null("NameLabel") as Label3D
	if label != null:
		var display_name := str(peer.get("display_name", ""))
		label.text = display_name if not display_name.is_empty() else "Player %s" % peer_id

func _select_from_screen_position(screen_position: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var origin := camera.project_ray_origin(screen_position)
	var end := origin + camera.project_ray_normal(screen_position) * RAY_LENGTH
	var query := PhysicsRayQueryParameters3D.create(origin, end, SELECTION_MASK)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var collider := hit.get("collider") as Node
	var peer_id := _peer_id_from_collider(collider)
	if peer_id <= 0 or not NetworkManager.peers.has(peer_id):
		return
	selected_peer_id = peer_id
	target_selected.emit(peer_id)

func _peer_id_from_collider(collider: Node) -> int:
	var current := collider
	while current != null and current != self:
		if current.has_meta("peer_id"):
			return int(current.get_meta("peer_id"))
		current = current.get_parent()
	return 0

func _on_roster_changed(peer_id: int) -> void:
	_refresh_roster(peer_id)
