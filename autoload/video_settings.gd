extends Node

signal settings_changed

const CONFIG_PATH := "user://gods_liars_settings.cfg"
const SECTION_VIDEO := "video"

var brightness: float = 1.0
var graphics_quality: int = 2
var display_mode: int = 1
var vsync_enabled: bool = true
var max_fps: int = 60

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
	vsync_enabled = bool(config.get_value(SECTION_VIDEO, "vsync_enabled", true))
	max_fps = int(config.get_value(SECTION_VIDEO, "max_fps", 60))

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION_VIDEO, "brightness", brightness)
	config.set_value(SECTION_VIDEO, "graphics_quality", graphics_quality)
	config.set_value(SECTION_VIDEO, "display_mode", display_mode)
	config.set_value(SECTION_VIDEO, "vsync_enabled", vsync_enabled)
	config.set_value(SECTION_VIDEO, "max_fps", max_fps)
	config.save(CONFIG_PATH)

func apply_settings() -> void:
	_apply_display_mode()
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED
	)
	Engine.max_fps = max_fps
	settings_changed.emit()

func set_brightness(value: float) -> void:
	brightness = clampf(value, 0.7, 1.3)
	_save_and_notify()

func set_graphics_quality(value: int) -> void:
	graphics_quality = clampi(value, 0, 3)
	_save_and_notify()

func set_display_mode(value: int) -> void:
	display_mode = clampi(value, 0, 2)
	_apply_display_mode()
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

func _apply_display_mode() -> void:
	match display_mode:
		0:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

func _save_and_notify() -> void:
	save_settings()
	settings_changed.emit()
