class_name PlayerPortraitCards
extends RefCounted

const PLAYER_AVATAR_SCENE := preload("res://scenes/player/player_avatar.tscn")
const PORTRAIT_SIZE := Vector2i(180, 138)

static func create_player_button(peer_id: int, minimum_size: Vector2 = Vector2(190, 210)) -> Button:
	var data: Dictionary = NetworkManager.peers.get(peer_id, {})
	var seat_id := int(data.get("seat_id", -1))
	var display_name := str(data.get("display_name", ""))
	if display_name.is_empty():
		display_name = "Acólito %d" % peer_id
	var player_color := PlayerColors.for_seat(seat_id)

	var button := Button.new()
	button.custom_minimum_size = minimum_size
	button.text = display_name
	button.tooltip_text = display_name
	button.set_meta("peer_id", peer_id)
	button.expand_icon = true
	button.add_theme_color_override("font_color", player_color)
	button.add_theme_color_override("font_hover_color", player_color.lightened(0.15))
	button.add_theme_color_override("font_pressed_color", player_color.lightened(0.25))

	var viewport := SubViewport.new()
	viewport.name = "PortraitViewport"
	viewport.size = PORTRAIT_SIZE
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	button.add_child(viewport)

	var world_root := Node3D.new()
	world_root.name = "PortraitWorld"
	viewport.add_child(world_root)

	var avatar := PLAYER_AVATAR_SCENE.instantiate() as Node3D
	avatar.name = "PortraitAvatar"
	world_root.add_child(avatar)
	if avatar is AvatarSlots:
		(avatar as AvatarSlots).set_player_color(player_color)
	var name_label := avatar.get_node_or_null("NameLabel") as Label3D
	if name_label != null:
		name_label.visible = false
	var selection_area := avatar.get_node_or_null("SelectionArea") as Area3D
	if selection_area != null:
		selection_area.monitoring = false
		selection_area.monitorable = false

	var camera := Camera3D.new()
	camera.name = "PortraitCamera"
	camera.fov = 32.0
	world_root.add_child(camera)
	camera.look_at_from_position(
		Vector3(0.0, 1.25, 3.1),
		Vector3(0.0, 1.05, 0.0),
		Vector3.UP
	)
	camera.current = true

	var key_light := DirectionalLight3D.new()
	key_light.name = "PortraitKey"
	key_light.light_energy = 1.8
	key_light.rotation_degrees = Vector3(-35.0, -25.0, 0.0)
	world_root.add_child(key_light)

	var fill_light := OmniLight3D.new()
	fill_light.name = "PortraitFill"
	fill_light.position = Vector3(0.8, 1.5, 1.8)
	fill_light.omni_range = 5.0
	fill_light.light_energy = 1.2
	world_root.add_child(fill_light)

	button.icon = viewport.get_texture()
	return button
