class_name PlayerChoiceGrid
extends GridContainer

signal peer_chosen(peer_id: int)

const PLAYER_AVATAR_SCENE := preload("res://scenes/player/player_avatar.tscn")
const PORTRAIT_SIZE := Vector2i(160, 120)

func _ready() -> void:
	columns = 4
	add_theme_constant_override("h_separation", 12)
	add_theme_constant_override("v_separation", 12)

func rebuild(peer_ids: Array[int], selected_peer_id: int = 0) -> void:
	for child in get_children():
		child.queue_free()
	for peer_id in peer_ids:
		add_child(_build_card(peer_id, peer_id == selected_peer_id))

func _build_card(peer_id: int, selected: bool) -> Button:
	var data: Dictionary = NetworkManager.peers.get(peer_id, {})
	var seat_id := int(data.get("seat_id", -1))
	var player_color := PlayerColors.for_seat(seat_id)
	var button := Button.new()
	button.custom_minimum_size = Vector2(190, 150)
	button.text = _peer_name(peer_id)
	button.toggle_mode = true
	button.button_pressed = selected
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", player_color)
	button.add_theme_color_override("font_hover_color", player_color.lightened(0.15))
	button.add_theme_color_override("font_pressed_color", player_color.lightened(0.25))
	button.tooltip_text = _peer_name(peer_id)

	var viewport := SubViewport.new()
	viewport.size = PORTRAIT_SIZE
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	button.add_child(viewport)

	var avatar := PLAYER_AVATAR_SCENE.instantiate() as Node3D
	viewport.add_child(avatar)
	avatar.position = Vector3.ZERO
	avatar.rotation.y = PI
	if avatar is AvatarSlots:
		(avatar as AvatarSlots).set_player_color(player_color)
	var avatar_label := avatar.get_node_or_null("NameLabel") as Label3D
	if avatar_label != null:
		avatar_label.visible = false
	var selection_area := avatar.get_node_or_null("SelectionArea") as Area3D
	if selection_area != null:
		selection_area.monitoring = false
		selection_area.monitorable = false

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35.0, -25.0, 0.0)
	light.light_energy = 1.6
	viewport.add_child(light)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.25, 2.65)
	viewport.add_child(camera)
	camera.look_at(Vector3(0.0, 1.2, 0.0), Vector3.UP)
	camera.current = true

	button.icon = viewport.get_texture()
	button.expand_icon = true
	button.pressed.connect(_emit_choice.bind(peer_id))
	return button

func _emit_choice(peer_id: int) -> void:
	peer_chosen.emit(peer_id)

func _peer_name(peer_id: int) -> String:
	var data: Dictionary = NetworkManager.peers.get(peer_id, {})
	var display_name := str(data.get("display_name", "")).strip_edges()
	return display_name if not display_name.is_empty() else "Jugador %d" % peer_id
