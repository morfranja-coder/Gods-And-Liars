extends Node3D

func _ready() -> void:
	_build_placeholder_table()
	_build_seat_markers()

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
