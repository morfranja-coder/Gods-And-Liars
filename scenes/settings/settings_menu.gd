extends Control

const LOBBY_SCENE := "res://scenes/lobby/lobby.tscn"

var _waiting_for_ptt_key: bool = false

@onready var brightness_slider: HSlider = %BrightnessSlider
@onready var brightness_value: Label = %BrightnessValue
@onready var quality_option: OptionButton = %QualityOption
@onready var display_option: OptionButton = %DisplayOption
@onready var vsync_check: CheckButton = %VsyncCheck
@onready var fps_option: OptionButton = %FpsOption
@onready var master_slider: HSlider = %MasterSlider
@onready var master_value: Label = %MasterValue
@onready var music_slider: HSlider = %MusicSlider
@onready var music_value: Label = %MusicValue
@onready var sfx_slider: HSlider = %SfxSlider
@onready var sfx_value: Label = %SfxValue
@onready var voice_slider: HSlider = %VoiceSlider
@onready var voice_value: Label = %VoiceValue
@onready var ptt_button: Button = %PttButton
@onready var back_button: Button = %BackButton

func _ready() -> void:
	_populate_options()
	_sync_from_settings()
	brightness_slider.value_changed.connect(_on_brightness_changed)
	quality_option.item_selected.connect(_on_quality_selected)
	display_option.item_selected.connect(_on_display_selected)
	vsync_check.toggled.connect(_on_vsync_toggled)
	fps_option.item_selected.connect(_on_fps_selected)
	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	voice_slider.value_changed.connect(_on_voice_changed)
	ptt_button.pressed.connect(_on_ptt_pressed)
	back_button.pressed.connect(_on_back_pressed)

func _unhandled_key_input(event: InputEvent) -> void:
	if not _waiting_for_ptt_key:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_ESCAPE:
		_waiting_for_ptt_key = false
		_update_ptt_button()
		get_viewport().set_input_as_handled()
		return
	AudioSettings.set_push_to_talk_key(key_event.physical_keycode)
	_waiting_for_ptt_key = false
	_update_ptt_button()
	get_viewport().set_input_as_handled()

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
	_update_percent(brightness_value, VideoSettings.brightness)
	quality_option.select(VideoSettings.graphics_quality)
	display_option.select(VideoSettings.display_mode)
	vsync_check.button_pressed = VideoSettings.vsync_enabled
	_select_fps(VideoSettings.max_fps)
	master_slider.value = AudioSettings.master_volume
	music_slider.value = AudioSettings.music_volume
	sfx_slider.value = AudioSettings.sfx_volume
	voice_slider.value = AudioSettings.voice_volume
	_update_percent(master_value, AudioSettings.master_volume)
	_update_percent(music_value, AudioSettings.music_volume)
	_update_percent(sfx_value, AudioSettings.sfx_volume)
	_update_percent(voice_value, AudioSettings.voice_volume)
	_update_ptt_button()

func _select_fps(target_fps: int) -> void:
	for index in fps_option.item_count:
		if fps_option.get_item_id(index) == target_fps:
			fps_option.select(index)
			return
	fps_option.select(1)

func _update_percent(label: Label, value: float) -> void:
	label.text = "%d%%" % roundi(value * 100.0)

func _update_ptt_button() -> void:
	ptt_button.text = "Presioná una tecla..." if _waiting_for_ptt_key else AudioSettings.push_to_talk_label()

func _on_brightness_changed(value: float) -> void:
	VideoSettings.set_brightness(value)
	_update_percent(brightness_value, value)

func _on_quality_selected(index: int) -> void:
	VideoSettings.set_graphics_quality(index)

func _on_display_selected(index: int) -> void:
	VideoSettings.set_display_mode(index)

func _on_vsync_toggled(enabled: bool) -> void:
	VideoSettings.set_vsync_enabled(enabled)

func _on_fps_selected(index: int) -> void:
	VideoSettings.set_max_fps(fps_option.get_item_id(index))

func _on_master_changed(value: float) -> void:
	AudioSettings.set_master_volume(value)
	_update_percent(master_value, value)

func _on_music_changed(value: float) -> void:
	AudioSettings.set_music_volume(value)
	_update_percent(music_value, value)

func _on_sfx_changed(value: float) -> void:
	AudioSettings.set_sfx_volume(value)
	_update_percent(sfx_value, value)

func _on_voice_changed(value: float) -> void:
	AudioSettings.set_voice_volume(value)
	_update_percent(voice_value, value)

func _on_ptt_pressed() -> void:
	_waiting_for_ptt_key = true
	_update_ptt_button()

func _on_back_pressed() -> void:
	var return_scene := LOBBY_SCENE
	if get_tree().root.has_meta("settings_return_scene"):
		return_scene = str(get_tree().root.get_meta("settings_return_scene"))
		get_tree().root.remove_meta("settings_return_scene")
	get_tree().change_scene_to_file(return_scene)
