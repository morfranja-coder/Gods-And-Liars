class_name TableCameraLook
extends Camera3D

@export_range(0.0005, 0.02, 0.0005) var mouse_sensitivity: float = 0.0025
@export_range(0.5, 6.0, 0.1) var controller_sensitivity: float = 2.2
@export_range(45.0, 160.0, 1.0) var yaw_limit_degrees: float = 110.0
@export_range(10.0, 80.0, 1.0) var pitch_up_limit_degrees: float = 45.0
@export_range(10.0, 80.0, 1.0) var pitch_down_limit_degrees: float = 35.0
@export_range(1.0, 30.0, 0.5) var smoothing_speed: float = 14.0

var look_enabled: bool = true
var _base_rotation: Vector3
var _target_yaw: float = 0.0
var _target_pitch: float = 0.0

func _ready() -> void:
	_base_rotation = rotation

func _process(delta: float) -> void:
	if not look_enabled:
		return
	_apply_controller_look(delta)
	_apply_smoothed_rotation(delta)

func _unhandled_input(event: InputEvent) -> void:
	if not look_enabled:
		return
	if event is not InputEventMouseMotion:
		return
	var motion := event as InputEventMouseMotion
	_apply_look_delta(motion.relative * mouse_sensitivity)

func set_look_enabled(enabled: bool) -> void:
	look_enabled = enabled

func anchor_to(anchor_transform: Transform3D) -> void:
	var camera_transform := Transform3D(
		anchor_transform.basis.orthonormalized(),
		anchor_transform.origin,
	)
	global_transform = camera_transform
	_base_rotation = rotation
	reset_look()

func reset_look() -> void:
	_target_yaw = 0.0
	_target_pitch = 0.0

func _apply_controller_look(delta: float) -> void:
	var horizontal := Input.get_axis(InputBindings.ACTION_LOOK_LEFT, InputBindings.ACTION_LOOK_RIGHT)
	var vertical := Input.get_axis(InputBindings.ACTION_LOOK_UP, InputBindings.ACTION_LOOK_DOWN)
	var look_vector := Vector2(horizontal, vertical)
	if look_vector.length_squared() <= 0.0001:
		return
	_apply_look_delta(look_vector * controller_sensitivity * delta)

func _apply_look_delta(delta: Vector2) -> void:
	_target_yaw -= delta.x
	_target_pitch -= delta.y
	_target_yaw = clampf(_target_yaw, -deg_to_rad(yaw_limit_degrees), deg_to_rad(yaw_limit_degrees))
	_target_pitch = clampf(
		_target_pitch,
		-deg_to_rad(pitch_down_limit_degrees),
		deg_to_rad(pitch_up_limit_degrees)
	)

func _apply_smoothed_rotation(delta: float) -> void:
	var target_rotation := _base_rotation + Vector3(_target_pitch, _target_yaw, 0.0)
	var weight := 1.0 - exp(-smoothing_speed * delta)
	rotation.x = lerp_angle(rotation.x, target_rotation.x, weight)
	rotation.y = lerp_angle(rotation.y, target_rotation.y, weight)
	rotation.z = _base_rotation.z
