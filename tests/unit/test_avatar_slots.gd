class_name AvatarSlotsTest
extends GdUnitTestSuite

const AVATAR_SCENE := preload("res://scenes/player/player_avatar.tscn")

func test_placeholder_body_survives_without_real_assets() -> void:
	var avatar := AVATAR_SCENE.instantiate()
	add_child(avatar)
	await get_tree().process_frame
	assert_object(avatar.get_node_or_null("Body/Placeholder")).is_not_null()
	avatar.queue_free()
