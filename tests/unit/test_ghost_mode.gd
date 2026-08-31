class_name GhostModeTest
extends GdUnitTestSuite

const GHOST_SCENE := preload("res://scenes/player/ghost_controller.tscn")
const HUD_SCENE := preload("res://scenes/table/ghost_hud.tscn")

func after_test() -> void:
	Input.action_release(InputBindings.ACTION_GHOST_FORWARD)
	InputBindings.set_text_entry_active(false)

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
	ghost._physics_process(0.016)
	assert_bool(ghost.velocity.length_squared() > 0.01).is_true()

	InputBindings.set_text_entry_active(true)
	ghost._physics_process(0.016)
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
