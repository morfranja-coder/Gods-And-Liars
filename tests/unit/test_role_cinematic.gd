extends GdUnitTestSuite

const SCENE := preload("res://scenes/table/role_reveal.tscn")


func after_test() -> void:
	GameManager.set_phase(GameManager.MatchPhase.LOBBY)
	MatchAuthority.local_role = PlayerState.Role.UNASSIGNED
	MatchAuthority.local_heretic_teammate_name = ""


func test_every_role_has_a_video_with_audio_bus() -> void:
	var presentation := SCENE.instantiate()
	add_child(presentation)
	for path in presentation.STREAMS.values():
		assert_bool(ResourceLoader.exists(path)).is_true()
		assert_object(load(path) as VideoStreamTheora).is_not_null()
	assert_str(str(presentation.video.bus)).is_equal("SFX")
	presentation.queue_free()
	await get_tree().process_frame


func test_titles_and_teammate_text_are_localized() -> void:
	assert_str(RoleRevealCopy.title(PlayerState.Role.HEALER, "es")).is_equal("Sacerdote")
	assert_str(RoleRevealCopy.title(PlayerState.Role.HEALER, "en")).is_equal("Priest")
	assert_str(RoleRevealCopy.title(PlayerState.Role.HERETIC, "pt")).is_equal("Herege")
	assert_str(RoleRevealCopy.title(PlayerState.Role.INQUISITOR, "fr")).is_equal("Inquisiteur")
	assert_str(RoleRevealCopy.title(PlayerState.Role.FAITHFUL, "unknown")).is_equal("Fiel")
	assert_str(RoleRevealCopy.description(PlayerState.Role.HERETIC, "en", "Mateo")).contains("Your teammate: Mateo")
	assert_str(RoleRevealCopy.description(PlayerState.Role.FAITHFUL, "es", "Mateo")).not_contains("Mateo")


func test_duplicate_private_events_do_not_restart_the_cinematic() -> void:
	GameManager.set_phase(GameManager.MatchPhase.ROLE_REVEAL)
	MatchAuthority.local_role = PlayerState.Role.HERETIC
	var presentation := SCENE.instantiate()
	add_child(presentation)
	var generation: int = presentation._generation
	presentation._on_private_role_received(PlayerState.Role.HERETIC)
	MatchAuthority.local_heretic_teammate_name = "Bruno"
	presentation._on_private_heretic_teammate_received(3, "Bruno")
	assert_int(presentation._generation).is_equal(generation)
	assert_str(presentation.description_label.text).contains("Bruno")
	assert_bool(presentation.blocks_gameplay_input()).is_true()
	presentation._on_phase_synced(GameManager.MatchPhase.NIGHT_START)
	assert_bool(presentation.panel.visible).is_false()
	assert_bool(presentation.video.is_playing()).is_false()
	presentation.queue_free()
	await get_tree().process_frame


func test_clip_and_transitions_fit_within_authority_deadline() -> void:
	var presentation := SCENE.instantiate()
	assert_float(presentation.CLIP_SECONDS + 2 * presentation.COVER_SECONDS).is_less(PhaseTimeoutPolicy.ROLE_REVEAL_MS / 1000.0)
	presentation.free()


func test_watermark_band_is_opaque_in_the_lower_corners() -> void:
	var presentation := SCENE.instantiate()
	add_child(presentation)
	var gradient: Gradient = presentation.shade.texture.gradient
	assert_float(gradient.sample(0.5).a).is_equal(1.0)
	assert_float(presentation.shade.anchor_right).is_equal(1.0)
	presentation.queue_free()
	await get_tree().process_frame
