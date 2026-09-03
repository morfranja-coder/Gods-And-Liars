class_name TableNameplates
extends CanvasLayer

const NAMEPLATE_SIZE := Vector2(220.0, 34.0)
const HEAD_SCREEN_OFFSET := Vector2(0.0, -26.0)

var _table: Node3D = null
var _labels: Dictionary = {}

func setup(table: Node3D) -> void:
	_table = table
	layer = 6

func _process(_delta: float) -> void:
	if _table == null or not is_instance_valid(_table):
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		_hide_all()
		return
	var local_peer_id := multiplayer.get_unique_id() if multiplayer.multiplayer_peer != null else 0
	var active_ids: Dictionary = {}
	for raw_peer_id in NetworkManager.peers.keys():
		var peer_id := int(raw_peer_id)
		if peer_id == local_peer_id or not MatchAuthority.is_peer_publicly_alive(peer_id):
			continue
		var avatar := _table.get_node_or_null("Peer_%s" % peer_id) as Node3D
		if avatar == null or not avatar.visible:
			continue
		var anchor := avatar.get_node_or_null("HeadAnchor") as Node3D
		var world_position := (
			anchor.global_position + Vector3.UP * 0.22
			if anchor != null
			else avatar.global_position + Vector3.UP * 2.0
		)
		if camera.is_position_behind(world_position):
			continue
		var label := _label_for(peer_id)
		var screen_position := camera.unproject_position(world_position)
		label.position = screen_position - NAMEPLATE_SIZE * 0.5 + HEAD_SCREEN_OFFSET
		label.visible = true
		active_ids[peer_id] = true
	for raw_peer_id in _labels.keys():
		if not active_ids.has(int(raw_peer_id)):
			var label := _labels[raw_peer_id] as Label
			if label != null:
				label.visible = false

func _label_for(peer_id: int) -> Label:
	if _labels.has(peer_id):
		return _labels[peer_id] as Label
	var data: Dictionary = NetworkManager.peers.get(peer_id, {})
	var display_name := str(data.get("display_name", "")).strip_edges()
	if display_name.is_empty():
		display_name = "Jugador %d" % peer_id
	var seat_id := int(data.get("seat_id", -1))
	var player_color := PlayerColors.for_seat(seat_id)
	var label := Label.new()
	label.name = "Nameplate_%s" % peer_id
	label.text = display_name
	label.custom_minimum_size = NAMEPLATE_SIZE
	label.size = NAMEPLATE_SIZE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", player_color)
	label.add_theme_color_override("font_outline_color", Color(0.015, 0.015, 0.02, 1.0))
	label.add_theme_constant_override("outline_size", 7)
	add_child(label)
	_labels[peer_id] = label
	return label

func _hide_all() -> void:
	for label in _labels.values():
		if label is Label:
			(label as Label).visible = false
