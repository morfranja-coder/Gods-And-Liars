extends Node3D

const PLAYER_AVATAR_SCENE := preload("res://scenes/player/player_avatar.tscn")

var _avatars: Dictionary = {}

func _ready() -> void:
	_build_placeholder_table()
	_build_seat_markers()
	NetworkManager.peer_joined.connect(_on_roster_changed)
	NetworkManager.peer_left.connect(_on_roster_changed)
	NetworkManager.peer_identity_updated.connect(_on_peer_identity_updated)
	_refresh_roster()

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
	if seat_id < 0 or seat_id >= TableLayout.SEAT_COUNT:
		return null
	return get_node_or_null("Seats/Seat_%02d" % (seat_id + 1)) as Marker3D

func _refresh_roster(_unused: int = 0) -> void:
	var active_ids: Array[int] = []
	var ordered_ids := NetworkManager.peers.keys()
	ordered_ids.sort()
	for index in range(mini(ordered_ids.size(), TableLayout.SEAT_COUNT)):
		var peer_id := int(ordered_ids[index])
		active_ids.append(peer_id)
		_spawn_or_update_avatar(peer_id, index)
	for raw_id in _avatars.keys():
		var peer_id := int(raw_id)
		if peer_id not in active_ids:
			var avatar: Node = _avatars[peer_id]
			avatar.queue_free()
			_avatars.erase(peer_id)

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
		add_child(avatar)
		_avatars[peer_id] = avatar
	avatar.global_transform = marker.global_transform
	var peer: Dictionary = NetworkManager.peers.get(peer_id, {})
	var label := avatar.get_node_or_null("NameLabel") as Label3D
	if label != null:
		var display_name := str(peer.get("display_name", ""))
		label.text = display_name if not display_name.is_empty() else "Player %s" % peer_id

func _on_roster_changed(peer_id: int) -> void:
	_refresh_roster(peer_id)

func _on_peer_identity_updated(_peer_id: int) -> void:
	_refresh_roster()
