class_name GhostModeTest
extends GdUnitTestSuite

const GHOST_SCENE := preload("res://scenes/player/ghost_controller.tscn")
const HUD_SCENE := preload("res://scenes/table/ghost_hud.tscn")

func after_test() -> void:
	Input.action_release(InputBindings.ACTION_GHOST_FORWARD)
	InputBindings.set_text_entry_active(false)
	MatchAuthority.reset()
	GameManager.reset_match()
	multiplayer.multiplayer_peer = null

func test_death_during_every_night_phase_removes_blackout() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	MatchAuthority.local_role = PlayerState.Role.FAITHFUL
	var ui := load("res://scenes/table/night_action_ui.tscn").instantiate() as Node
	add_child(ui)
	for phase in [GameManager.MatchPhase.NIGHT_START, GameManager.MatchPhase.HERETIC_ACTION,
		GameManager.MatchPhase.HEALER_ACTION, GameManager.MatchPhase.INQUISITOR_ACTION]:
		MatchAuthority.public_alive_by_peer[1] = true
		MatchAuthority._sync_phase(phase, 2)
		await get_tree().process_frame
		assert_bool(ui.get_node("BlackOverlay").visible).is_true()
		# Die without changing phase: the next frame must restore spectator vision.
		MatchAuthority.public_alive_by_peer[1] = false
		await get_tree().process_frame
		assert_bool(ui.get_node("BlackOverlay").visible).is_false()
		assert_bool(ui.get_node("Panel").visible).is_false()
	ui.queue_free()
	await get_tree().process_frame

func test_ghost_role_selects_the_matching_visual() -> void:
	var ghost := GHOST_SCENE.instantiate() as GhostController
	add_child(ghost)
	ghost.activate(true)
	assert_bool(ghost.get_node("BodyVisual/HereticGhost").visible).is_true()
	assert_bool(ghost.get_node("BodyVisual/InnocentGhost").visible).is_false()
	assert_bool((ghost.get_node("HeadPivot/Camera3D") as Camera3D).current).is_true()
	ghost.queue_free()

func test_text_entry_suppresses_ghost_movement() -> void:
	var ghost := GHOST_SCENE.instantiate() as GhostController
	add_child(ghost)
	ghost.activate(false)
	Input.action_press(InputBindings.ACTION_GHOST_FORWARD)
	ghost._process(0.016)
	assert_bool(ghost.velocity.length_squared() > 0.01).is_true()

	InputBindings.set_text_entry_active(true)
	ghost._process(0.016)
	assert_vector(ghost.velocity).is_equal(Vector3.ZERO)
	ghost.queue_free()

func test_ghost_hud_exposes_state_and_controls() -> void:
	var hud := HUD_SCENE.instantiate() as GhostHUD
	add_child(hud)
	hud.show_ghost_mode(false)
	assert_bool(hud.visible).is_true()
	assert_str((hud.get_node("StatePanel/VBox/StateLabel") as Label).text).is_equal(
		"ESPECTRO FIEL"
	)
	assert_str((hud.get_node("ControlsPanel/Controls") as Label).text).contains("WASD")
	hud.queue_free()
