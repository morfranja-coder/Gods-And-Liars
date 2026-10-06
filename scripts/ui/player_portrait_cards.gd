class_name PlayerPortraitCards
extends RefCounted

const MASK_TEXTURE := preload("res://assets/ui/player_mask.png")

static func create_mask(peer_id: int, minimum_size: Vector2) -> TextureRect:
	var data: Dictionary = NetworkManager.peers.get(peer_id, {})
	var mask := TextureRect.new()
	mask.name = "PlayerMask"
	mask.texture = MASK_TEXTURE
	mask.modulate = PlayerColors.for_seat(int(data.get("seat_id", -1)))
	mask.custom_minimum_size = minimum_size
	mask.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mask.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return mask

static func create_player_button(peer_id: int, minimum_size: Vector2 = Vector2(190, 210)) -> Button:
	var data: Dictionary = NetworkManager.peers.get(peer_id, {})
	var display_name := str(data.get("display_name", "Acólito %d" % peer_id))
	var button := Button.new()
	button.custom_minimum_size = minimum_size
	button.tooltip_text = display_name
	button.toggle_mode = true
	button.set_meta("peer_id", peer_id)
	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 10
	content.offset_top = 10
	content.offset_right = -10
	content.offset_bottom = -10
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(content)
	var mask := create_mask(peer_id, Vector2(0, 138))
	mask.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(mask)
	var label := Label.new()
	label.text = display_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", mask.modulate)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(label)
	return button
