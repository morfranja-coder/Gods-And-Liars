extends Control

const LOBBY_SCENE := "res://scenes/lobby/lobby.tscn"

@onready var brightness_slider: HSlider = %BrightnessSlider
@onready var brightness_value: Label = %BrightnessValue
@onready var quality_option: OptionButton = %QualityOption
@onready var display_option: OptionButton = %DisplayOption
@onready var vsync_check: CheckButton = %VsyncCheck
@onready var fps_option: OptionButton = %FpsOption
@onready var back_button: Button = %BackButton

func _ready() -> void:
	_populate_options()
	_sync_from_settings()
	brightness_slider.value_changed.connect(_on_brightness_changed)
	quality_option.item_selected.connect(_on_quality_selected)
	display_option.item_selected.connect(_on_display_selected)
	vsync_check.toggled.connect(_on_vsync_toggled)
	fps_option.item_selected.connect(_on_fps_selected)
	back_button.pressed.connect(_on_back_pressed)

func _populate_options() -> void:
	quality_option.clear()
	for label in ["Baja", "Media", "Alta", "Ultra"]:
		quality_option.add_item(label)
	display_option.clear()
	for label in ["Ventana", "Pantalla completa", "Pantalla completa exclusiva"]:
		display_option.add_item(label)
	fps_option.clear()
	for fps in [30, 60, 120, 144, 0]:
		var label := "Sin límite" if fps == 0 else "%d FPS" % fps
		fps_option.add_item(label, fps)

func _sync_from_settings() -> void:
	brightness_slider.value = VideoSettings.brightness
	_update_brightness_label(VideoSettings.brightness)
	quality_option.select(VideoSettings.graphics_quality)
	display_option.select(VideoSettings.display_mode)
	vsync_check.button_pressed = VideoSettings.vsync_enabled
	_select_fps(VideoSettings.max_fps)

func _select_fps(target_fps: int) -> void:
	for index in fps_option.item_count:
		if fps_option.get_item_id(index) == target_fps:
			fps_option.select(index)
			return
	fps_option.select(1)

func _on_brightness_changed(value: float) -> void:
	VideoSettings.set_brightness(value)
	_update_brightness_label(value)

func _update_brightness_label(value: float) -> void:
	brightness_value.text = "%d%%" % roundi(value * 100.0)

func _on_quality_selected(index: int) -> void:
	VideoSettings.set_graphics_quality(index)

func _on_display_selected(index: int) -> void:
	VideoSettings.set_display_mode(index)

func _on_vsync_toggled(enabled: bool) -> void:
	VideoSettings.set_vsync_enabled(enabled)

func _on_fps_selected(index: int) -> void:
	VideoSettings.set_max_fps(fps_option.get_item_id(index))

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(LOBBY_SCENE)
