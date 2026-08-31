extends CanvasLayer

signal leave_pressed

var is_open: bool = false

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
@onready var mute_player_option: OptionButton = %MutePlayerOption
@onready var toggle_mute_button: Button = %ToggleMuteButton
@onready var leave_button: Button = %LeaveButton
@onready var leave_status_label: Label = %LeaveStatusLabel

func _ready() -> void:
	_populate_options()
	_sync_from_settings()
	resume_button.pressed.connect(close)
	options_button.pressed.connect(_toggle_options)
	brightness_slider.value_changed.connect(_on_brightness_changed)
	quality_option.item_selected.connect(_on_quality_selected)
	vsync_check.toggled.connect(_on_vsync_toggled)
	fps_option.item_selected.connect(_on_fps_selected)
	mute_player_option.item_selected.connect(_on_mute_player_selected)
	toggle_mute_button.pressed.connect(_on_toggle_mute_pressed)
	AudioSettings.peer_mute_changed.connect(_on_peer_mute_changed)
	NetworkManager.peer_joined.connect(_on_peer_changed)
	NetworkManager.peer_left.connect(_on_peer_changed)
	NetworkManager.peer_updated.connect(_on_peer_changed)
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
	_refresh_mute_players()
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
	if options_panel.visible:
		_refresh_mute_players()

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

func _refresh_mute_players() -> void:
	mute_player_option.clear()
	var local_id := multiplayer.get_unique_id() if multiplayer.multiplayer_peer != null else 0
	var ids := NetworkManager.peers.keys()
	ids.sort()
	for raw_peer_id in ids:
		var peer_id := int(raw_peer_id)
		if peer_id == local_id:
			continue
		var data: Dictionary = NetworkManager.peers.get(peer_id, {})
		var display_name := str(data.get("display_name", "Jugador %s" % peer_id))
		mute_player_option.add_item(display_name, peer_id)
	mute_player_option.disabled = mute_player_option.item_count == 0
	toggle_mute_button.disabled = mute_player_option.item_count == 0
	_update_mute_button()

func _selected_mute_peer_id() -> int:
	if mute_player_option.item_count == 0:
		return 0
	return mute_player_option.get_item_id(mute_player_option.selected)

func _update_mute_button() -> void:
	var peer_id := _selected_mute_peer_id()
	if peer_id <= 0:
		toggle_mute_button.text = "Silenciar jugador"
		return
	toggle_mute_button.text = (
		"Volver a escuchar" if AudioSettings.is_peer_muted(peer_id) else "Silenciar jugador"
	)

func _on_brightness_changed(value: float) -> void:
	VideoSettings.set_brightness(value)
	brightness_value.text = "%d%%" % roundi(value * 100.0)

func _on_quality_selected(index: int) -> void:
	VideoSettings.set_graphics_quality(index)

func _on_vsync_toggled(enabled: bool) -> void:
	VideoSettings.set_vsync_enabled(enabled)

func _on_fps_selected(index: int) -> void:
	VideoSettings.set_max_fps(fps_option.get_item_id(index))

func _on_mute_player_selected(_index: int) -> void:
	_update_mute_button()

func _on_toggle_mute_pressed() -> void:
	var peer_id := _selected_mute_peer_id()
	if peer_id <= 0:
		return
	AudioSettings.toggle_peer_muted(peer_id)
	_update_mute_button()

func _on_peer_mute_changed(_peer_id: int, _muted: bool) -> void:
	_update_mute_button()

func _on_peer_changed(_peer_id: int) -> void:
	if is_open:
		_refresh_mute_players()

func _on_leave_pressed() -> void:
	leave_pressed.emit()
