class_name GhostController
extends CharacterBody3D

const HERETIC_GHOST_FOLDER := "res://assets/FantasmaHereje"
const INNOCENT_GHOST_FOLDER := "res://assets/FantasmaPJ"

@export_range(0.5, 10.0, 0.1) var move_speed := 2.8
@export_range(0.5, 10.0, 0.1) var vertical_speed := 2.0
@export_range(1.0, 20.0, 0.5) var body_follow_speed := 6.0
@export_range(0.0005, 0.02, 0.0005) var mouse_sensitivity := 0.0025
@export_range(0.5, 6.0, 0.1) var controller_sensitivity := 2.2
@export_range(20.0, 89.0, 1.0) var pitch_limit_degrees := 75.0
@export_range(1.0, 64.0, 1.0) var edge_turn_margin_pixels := 18.0
@export_range(15.0, 180.0, 5.0) var edge_turn_speed_degrees := 75.0

var input_enabled := false
var _target_yaw := 0.0
var _target_pitch := 0.0
var _movement_player: AnimationPlayer = null

@onready var body_visual: Node3D = $BodyVisual
@onready var head_pivot: Node3D = $HeadPivot
@onready var ghost_camera: Camera3D = $HeadPivot/Camera3D
@onready var heretic_visual: Node3D = $BodyVisual/HereticGhost
@onready var innocent_visual: Node3D = $BodyVisual/InnocentGhost

func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	call_deferred("_ensure_environment_collisions")

func _physics_process(delta: float) -> void:
	if not input_enabled or InputBindings.text_entry_active:
		velocity = Vector3.ZERO
		return
	_apply_controller_look(delta)
	_apply_edge_turn(delta)
	_apply_view_rotation()
	_apply_body_follow(delta)
	_apply_movement()
	_update_movement_animation()
	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or InputBindings.text_entry_active:
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		_apply_look_delta(motion.relative * mouse_sensitivity)

func activate(is_heretic: bool) -> void:
	_ensure_environment_collisions()
	_ensure_visual_loaded(
		heretic_visual if is_heretic else innocent_visual,
		HERETIC_GHOST_FOLDER if is_heretic else INNOCENT_GHOST_FOLDER,
	)
	heretic_visual.visible = is_heretic
	innocent_visual.visible = not is_heretic
	_movement_player = _find_animation_player(
		heretic_visual if is_heretic else innocent_visual
	)
	input_enabled = true
	ghost_camera.current = true

func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	if not input_enabled:
		velocity = Vector3.ZERO

func _ensure_environment_collisions() -> void:
	var table_root := get_parent()
	if table_root == null or not table_root.has_method("_add_scenario_collisions_recursive"):
		return
	var collision_roots: Array[Node] = []
	var alpha_scenario := table_root.get_node_or_null("AlphaScenario")
	if alpha_scenario != null:
		collision_roots.append(alpha_scenario)
	for child in table_root.get_children():
		if child is not Node3D:
			continue
		var node_name := str(child.name).to_lower()
		if not _is_environment_collision_root(node_name):
			continue
		if child not in collision_roots:
			collision_roots.append(child)
	for root in collision_roots:
		table_root.call("_add_scenario_collisions_recursive", root)

func _is_environment_collision_root(node_name: String) -> bool:
	return (
		node_name.begins_with("alphascenario")
		or node_name.begins_with("escenarioalfa")
		or node_name.begins_with("techo")
		or node_name.begins_with("ceiling")
	)

func _apply_controller_look(delta: float) -> void:
	var horizontal := Input.get_axis(InputBindings.ACTION_LOOK_LEFT, InputBindings.ACTION_LOOK_RIGHT)
	var vertical := Input.get_axis(InputBindings.ACTION_LOOK_UP, InputBindings.ACTION_LOOK_DOWN)
	_apply_look_delta(Vector2(horizontal, vertical) * controller_sensitivity * delta)

func _apply_edge_turn(delta: float) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0:
		return
	var mouse_x := get_viewport().get_mouse_position().x
	var edge_direction := 0.0
	if mouse_x <= edge_turn_margin_pixels:
		edge_direction = -1.0
	elif mouse_x >= viewport_size.x - edge_turn_margin_pixels:
		edge_direction = 1.0
	if is_zero_approx(edge_direction):
		return
	_target_yaw -= edge_direction * deg_to_rad(edge_turn_speed_degrees) * delta

func _apply_look_delta(look_delta: Vector2) -> void:
	_target_yaw -= look_delta.x
	_target_pitch = clampf(
		_target_pitch - look_delta.y,
		-deg_to_rad(pitch_limit_degrees),
		deg_to_rad(pitch_limit_degrees)
	)

func _apply_view_rotation() -> void:
	head_pivot.rotation = Vector3(_target_pitch, _target_yaw, 0.0)

func _apply_body_follow(delta: float) -> void:
	var weight := 1.0 - exp(-body_follow_speed * delta)
	body_visual.rotation.y = lerp_angle(body_visual.rotation.y, _target_yaw, weight)

func _apply_movement() -> void:
	var input_vector := Input.get_vector(
		InputBindings.ACTION_GHOST_LEFT,
		InputBindings.ACTION_GHOST_RIGHT,
		InputBindings.ACTION_GHOST_FORWARD,
		InputBindings.ACTION_GHOST_BACK
	)
	var camera_basis := ghost_camera.global_basis
	var forward := -camera_basis.z
	var right := camera_basis.x
	forward.y = 0.0
	right.y = 0.0
	var planar := (
		right.normalized() * input_vector.x
		+ forward.normalized() * -input_vector.y
	)
	var vertical := Input.get_axis(
		InputBindings.ACTION_GHOST_DESCEND,
		InputBindings.ACTION_GHOST_ASCEND
	)
	velocity = planar.limit_length(1.0) * move_speed + Vector3.UP * vertical * vertical_speed

func _update_movement_animation() -> void:
	if _movement_player == null:
		return
	var movement_animation := &"Ghost_Move_Forward"
	if velocity.length_squared() > 0.01:
		if _movement_player.current_animation != movement_animation:
			_movement_player.play(movement_animation, 0.18)
	elif not _movement_player.current_animation.is_empty():
		_movement_player.stop()

func _ensure_visual_loaded(root: Node3D, folder_path: String) -> void:
	if root.get_child_count() > 0:
		return
	var scene := _load_first_glb(folder_path)
	if scene != null:
		root.add_child(scene.instantiate())

func _load_first_glb(folder_path: String) -> PackedScene:
	var directory := DirAccess.open(folder_path)
	if directory == null:
		return null
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.get_extension().to_lower() == "glb":
			var resource := ResourceLoader.load(folder_path.path_join(file_name))
			directory.list_dir_end()
			return resource as PackedScene
		file_name = directory.get_next()
	directory.list_dir_end()
	return null

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null
