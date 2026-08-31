extends CanvasLayer

signal leave_pressed

@onready var veil: ColorRect = %Veil
@onready var panel: PanelContainer = %Panel
@onready var resume_button: Button = %ResumeButton
@onready var options_button: Button = %OptionsButton
@onready var options_panel: VBoxContainer = %OptionsPanel
@onready var brightness_slider: HSlider = %BrightnessSlider
@onready var brightness_value: Label = %BrightnessValue
@onready var quality_option: OptionButton = %QualityOption
@onready var vsync_check: CheckButton = %VsyncCheck
@onready var fps_option: OptionButton = %FpsOption
@onready var leave_button: Button = %LeaveButton
@onready var leave_status_label: Label = %LeaveStatusLabel

var is_open: bool = false

func _ready() -> void:
	_populate_options()
	_sync_from_settings()
	resume_button.pressed.connect(close)
	options_button.pressed.connect(_toggle_options)
	brightness_slider.value_changed.connect(_on_brightness_changed)
	quality_option.item_selected.connect(_on_quality_selected)
	vsync_check.toggled.connect(_on_vsync_toggled)
	fps_option.item_selected.connect(_on_fps_selected)
	leave_button.pressed.connect(_on_leave_pressed)
	_set_visible(false)

func toggle() -> void:
	if is_open:
		close()
	else:
		open()

func open() -> void:
	is_open = true
	_sync_from_settings()
	_set_visible(true)
	resume_button.grab_focus()

func close() -> void:
	is_open = false
	options_panel.visible = false
	_set_visible(false)

func set_leave_pending(pending: bool, message: String = "") -> void:
	leave_button.disabled = pending
	leave_status_label.text = message

func show_leave_error(message: String) -> void:
	leave_button.disabled = false
	leave_status_label.text = message

func _set_visible(value: bool) -> void:
	veil.visible = value
	panel.visible = value

func _toggle_options() -> void:
	options_panel.visible = not options_panel.visible
	options_button.text = "Ocultar opciones" if options_panel.visible else "Opciones"

func _populate_options() -> void:
	quality_option.clear()
	for label in ["Baja", "Media", "Alta", "Ultra"]:
		quality_option.add_item(label)
	fps_option.clear()
	for fps in [30, 60, 120, 144, 0]:
		var label := "Sin límite" if fps == 0 else "%d FPS" % fps
		fps_option.add_item(label, fps)

func _sync_from_settings() -> void:
	brightness_slider.value = VideoSettings.brightness
	brightness_value.text = "%d%%" % roundi(VideoSettings.brightness * 100.0)
	quality_option.select(VideoSettings.graphics_quality)
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
	brightness_value.text = "%d%%" % roundi(value * 100.0)

func _on_quality_selected(index: int) -> void:
	VideoSettings.set_graphics_quality(index)

func _on_vsync_toggled(enabled: bool) -> void:
	VideoSettings.set_vsync_enabled(enabled)

func _on_fps_selected(index: int) -> void:
	VideoSettings.set_max_fps(fps_option.get_item_id(index))

func _on_leave_pressed() -> void:
	leave_pressed.emit()
