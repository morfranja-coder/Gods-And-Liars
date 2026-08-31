extends Node

signal settings_changed

const CONFIG_PATH := "user://gods_liars_settings.cfg"
const SECTION_VIDEO := "video"
const RESOLUTIONS := [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]
const SHADOW_ATLAS_SIZES := [1024, 2048, 4096, 4096]
const QUALITY_RENDER_SCALES := [0.7, 0.8, 1.0, 1.0]
const QUALITY_SHADOW_LEVELS := [0, 1, 2, 3]

var brightness: float = 1.0
var graphics_quality: int = 2
var display_mode: int = 1
var resolution_index: int = 2
var vsync_enabled: bool = true
var max_fps: int = 60
var render_scale: float = 1.0
var shadow_quality: int = 2

func _ready() -> void:
	load_settings()
	apply_settings()

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	brightness = clampf(float(config.get_value(SECTION_VIDEO, "brightness", 1.0)), 0.7, 1.3)
	graphics_quality = clampi(int(config.get_value(SECTION_VIDEO, "graphics_quality", 2)), 0, 3)
	display_mode = clampi(int(config.get_value(SECTION_VIDEO, "display_mode", 1)), 0, 2)
	resolution_index = clampi(int(config.get_value(SECTION_VIDEO, "resolution_index", 2)), 0, RESOLUTIONS.size() - 1)
	vsync_enabled = bool(config.get_value(SECTION_VIDEO, "vsync_enabled", true))
	max_fps = int(config.get_value(SECTION_VIDEO, "max_fps", 60))
	render_scale = clampf(float(config.get_value(SECTION_VIDEO, "render_scale", 1.0)), 0.5, 1.0)
	shadow_quality = clampi(int(config.get_value(SECTION_VIDEO, "shadow_quality", 2)), 0, 3)

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION_VIDEO, "brightness", brightness)
	config.set_value(SECTION_VIDEO, "graphics_quality", graphics_quality)
	config.set_value(SECTION_VIDEO, "display_mode", display_mode)
	config.set_value(SECTION_VIDEO, "resolution_index", resolution_index)
	config.set_value(SECTION_VIDEO, "vsync_enabled", vsync_enabled)
	config.set_value(SECTION_VIDEO, "max_fps", max_fps)
	config.set_value(SECTION_VIDEO, "render_scale", render_scale)
	config.set_value(SECTION_VIDEO, "shadow_quality", shadow_quality)
	config.save(CONFIG_PATH)

func apply_settings() -> void:
	_apply_display_mode()
	_apply_resolution()
	_apply_runtime_quality()
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED
	)
	Engine.max_fps = max_fps
	settings_changed.emit()

func resolution_count() -> int:
	return RESOLUTIONS.size()

func resolution_at(index: int) -> Vector2i:
	if index < 0 or index >= RESOLUTIONS.size():
		return RESOLUTIONS[2]
	return RESOLUTIONS[index]

func resolution_label(index: int) -> String:
	var size := resolution_at(index)
	return "%d x %d" % [size.x, size.y]

func set_brightness(value: float) -> void:
	brightness = clampf(value, 0.7, 1.3)
	_save_and_notify()

func set_graphics_quality(value: int) -> void:
	graphics_quality = clampi(value, 0, 3)
	render_scale = QUALITY_RENDER_SCALES[graphics_quality]
	shadow_quality = QUALITY_SHADOW_LEVELS[graphics_quality]
	_apply_runtime_quality()
	_save_and_notify()

func set_display_mode(value: int) -> void:
	display_mode = clampi(value, 0, 2)
	_apply_display_mode()
	_apply_resolution()
	_save_and_notify()

func set_resolution_index(value: int) -> void:
	resolution_index = clampi(value, 0, RESOLUTIONS.size() - 1)
	_apply_resolution()
	_save_and_notify()

func set_vsync_enabled(value: bool) -> void:
	vsync_enabled = value
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED
	)
	_save_and_notify()

func set_max_fps(value: int) -> void:
	max_fps = value
	Engine.max_fps = max_fps
	_save_and_notify()

func set_render_scale(value: float) -> void:
	render_scale = clampf(value, 0.5, 1.0)
	_apply_runtime_quality()
	_save_and_notify()

func set_shadow_quality(value: int) -> void:
	shadow_quality = clampi(value, 0, 3)
	_apply_runtime_quality()
	_save_and_notify()

func apply_to_environment(environment: Environment) -> void:
	if environment == null:
		return
	environment.adjustment_enabled = true
	environment.adjustment_brightness = brightness

func _apply_display_mode() -> void:
	match display_mode:
		0:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

func _apply_resolution() -> void:
	if display_mode != 0:
		return
	DisplayServer.window_set_size(resolution_at(resolution_index))

func _apply_runtime_quality() -> void:
	var root := get_tree().root
	root.scaling_3d_scale = render_scale
	root.positional_shadow_atlas_size = SHADOW_ATLAS_SIZES[shadow_quality]

func _save_and_notify() -> void:
	save_settings()
	settings_changed.emit()
