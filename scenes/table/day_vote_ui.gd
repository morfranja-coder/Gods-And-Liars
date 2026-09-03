extends CanvasLayer

const PLAYER_AVATAR_SCENE := preload("res://scenes/player/player_avatar.tscn")

var selected_peer_id: int = 0
var _target_grid: GridContainer = null
var _target_buttons: Dictionary = {}
var _portrait_viewports: Array[SubViewport] = []
var _timer_label: Label = null
var _last_timer_second := -1

@onready var panel: PanelContainer = $Panel
@onready var vbox: VBoxContainer = $Panel/VBox
@onready var phase_label: Label = $Panel/VBox/PhaseLabel
@onready var target_label: Label = $Panel/VBox/TargetLabel
@onready var begin_button: Button = $Panel/VBox/BeginVotingButton
@onready var vote_button: Button = $Panel/VBox/VoteButton
@onready var result_label: Label = $Panel/VBox/ResultLabel

func _ready() -> void:
	_build_timer_label()
	_build_target_grid()
	begin_button.visible = false
	vote_button.pressed.connect(_on_vote_pressed)
	MatchAuthority.phase_synced.connect(_on_phase_synced)
	MatchAuthority.sacrifice_reveal_received.connect(_on_sacrifice_reveal_received)
	NetworkManager.peer_joined.connect(_on_roster_changed)
	NetworkManager.peer_left.connect(_on_roster_changed)
	NetworkManager.peer_updated.connect(_on_roster_changed)
	_refresh()

func _process(_delta: float) -> void:
	var seconds := MatchAuthority.phase_seconds_remaining()
	if seconds == _last_timer_second:
		return
	_last_timer_second = seconds
	if _timer_label != null:
		_timer_label.text = "%02d:%02d" % [seconds / 60, seconds % 60]

func _build_timer_label() -> void:
	_timer_label = Label.new()
	_timer_label.name = "TimerLabel"
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(_timer_label)
	vbox.move_child(_timer_label, 1)

func _build_target_grid() -> void:
	_target_grid = GridContainer.new()
	_target_grid.name = "TargetGrid"
	_target_grid.columns = 4
	_target_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_target_grid.add_theme_constant_override("h_separation", 10)
	_target_grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(_target_grid)
	vbox.move_child(_target_grid, 3)

func _on_phase_synced(_phase: int) -> void:
	selected_peer_id = 0
	_last_timer_second = -1
	result_label.text = ""
	if GameManager.phase == GameManager.MatchPhase.VOTING:
		_rebuild_target_cards()
	else:
		_clear_target_cards()
	_refresh()

func _on_roster_changed(_peer_id: int) -> void:
	if GameManager.phase == GameManager.MatchPhase.VOTING:
		_rebuild_target_cards()
	_refresh()

func _on_vote_pressed() -> void:
	var local_peer_id := _local_peer_id()
	if not _valid_selected_target(local_peer_id):
		result_label.text = "Elegí una máscara antes de confirmar el voto."
		_refresh()
		return
	MatchAuthority.submit_local_vote(selected_peer_id)
	result_label.text = "Voto registrado. Podés cambiarlo hasta que se termine el tiempo."

func _on_sacrifice_reveal_received(
	sacrificed_peer_id: int,
	tied: bool,
	was_heretic: bool
) -> void:
	if sacrificed_peer_id <= 0:
		result_label.text = "La votación terminó sin un acusado válido."
		_refresh()
		return
	var name := _peer_name(sacrificed_peer_id)
	var prefix := "Hubo empate. El destino eligió a %s. " % name if tied else "%s fue elegido. " % name
	result_label.text = prefix + (
		"Un Hereje fue sacrificado."
		if was_heretic
		else "Un inocente fue sacrificado."
	)
	_refresh()

func _refresh() -> void:
	var is_discussion := GameManager.phase == GameManager.MatchPhase.DAY_DISCUSSION
	var is_voting := GameManager.phase == GameManager.MatchPhase.VOTING
	var is_sacrifice := GameManager.phase == GameManager.MatchPhase.SACRIFICE
	var local_peer_id := _local_peer_id()
	var local_alive := local_peer_id > 0 and MatchAuthority.is_peer_publicly_alive(local_peer_id)
	var local_ghost := MatchAuthority.is_local_ghost()

	panel.visible = is_discussion or is_voting or is_sacrifice
	if not panel.visible:
		return
	phase_label.text = "DÍA %d" % (GameManager.round_number + 1)
	begin_button.visible = false
	if _target_grid != null:
		_target_grid.visible = is_voting and local_alive and not local_ghost
	target_label.visible = is_voting and local_alive and not local_ghost
	vote_button.visible = is_voting and local_alive and not local_ghost
	vote_button.disabled = not _valid_selected_target(local_peer_id)
	if local_ghost:
		target_label.visible = true
		target_label.text = "Ya no participás del juicio. El ritual continúa entre los vivos."
	elif is_discussion:
		target_label.visible = true
		target_label.text = "Tienen un minuto para discutir antes de la votación."
	elif is_voting:
		target_label.text = (
			"Tu voto: %s" % _peer_name(selected_peer_id)
			if selected_peer_id > 0
			else "Elegí una de las máscaras del panel"
		)
	elif is_sacrifice:
		target_label.visible = true
		target_label.text = "El dios dicta el resultado del juicio."

func _rebuild_target_cards() -> void:
	_clear_target_cards()
	var local_peer_id := _local_peer_id()
	var peer_ids := NetworkManager.peers.keys()
	peer_ids.sort_custom(func(a, b):
		var seat_a := int((NetworkManager.peers[a] as Dictionary).get("seat_id", 99))
		var seat_b := int((NetworkManager.peers[b] as Dictionary).get("seat_id", 99))
		return seat_a < seat_b
	)
	for raw_peer_id in peer_ids:
		var peer_id := int(raw_peer_id)
		if peer_id == local_peer_id or not MatchAuthority.is_peer_publicly_alive(peer_id):
			continue
		_add_target_card(peer_id)

func _add_target_card(peer_id: int) -> void:
	var data: Dictionary = NetworkManager.peers.get(peer_id, {})
	var seat_id := int(data.get("seat_id", 0))
	var player_color := PlayerColors.for_seat(seat_id)
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(150, 180)
	card.alignment = BoxContainer.ALIGNMENT_CENTER

	var portrait_button := Button.new()
	portrait_button.custom_minimum_size = Vector2(145, 135)
	portrait_button.toggle_mode = true
	portrait_button.expand_icon = true
	portrait_button.icon_max_width = 120
	portrait_button.tooltip_text = _peer_name(peer_id)
	portrait_button.button_pressed = peer_id == selected_peer_id
	portrait_button.pressed.connect(_select_target.bind(peer_id))
	portrait_button.icon = _create_portrait(player_color)
	portrait_button.add_theme_stylebox_override("normal", _card_style(player_color, false))
	portrait_button.add_theme_stylebox_override("hover", _card_style(player_color, true))
	portrait_button.add_theme_stylebox_override("pressed", _card_style(player_color, true))
	card.add_child(portrait_button)

	var name_label := Label.new()
	name_label.text = _peer_name(peer_id)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", player_color)
	name_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 1.0))
	name_label.add_theme_constant_override("outline_size", 5)
	name_label.add_theme_font_size_override("font_size", 17)
	card.add_child(name_label)

	_target_grid.add_child(card)
	_target_buttons[peer_id] = portrait_button

func _create_portrait(player_color: Color) -> Texture2D:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(192, 160)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	_portrait_viewports.append(viewport)

	var avatar := PLAYER_AVATAR_SCENE.instantiate() as Node3D
	viewport.add_child(avatar)
	if avatar is AvatarSlots:
		(avatar as AvatarSlots).set_player_color(player_color)
	var name_label := avatar.get_node_or_null("NameLabel") as Label3D
	if name_label != null:
		name_label.visible = false

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35.0, -25.0, 0.0)
	light.light_energy = 2.0
	viewport.add_child(light)

	var camera := Camera3D.new()
	camera.fov = 34.0
	viewport.add_child(camera)
	camera.position = Vector3(0.0, 1.25, 3.2)
	camera.look_at(Vector3(0.0, 1.2, 0.0), Vector3.UP)
	camera.current = true
	return viewport.get_texture()

func _card_style(color: Color, highlighted: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.035, 0.045, 0.96)
	style.border_color = color.lightened(0.2) if highlighted else color
	var width := 4 if highlighted else 2
	style.set_border_width_all(width)
	style.set_corner_radius_all(8)
	return style

func _select_target(peer_id: int) -> void:
	if GameManager.phase != GameManager.MatchPhase.VOTING:
		return
	if not MatchAuthority.is_peer_publicly_alive(peer_id):
		return
	selected_peer_id = peer_id
	for raw_id in _target_buttons.keys():
		var button := _target_buttons[raw_id] as Button
		if button != null:
			button.button_pressed = int(raw_id) == selected_peer_id
	target_label.text = "Tu voto: %s" % _peer_name(selected_peer_id)
	vote_button.disabled = not _valid_selected_target(_local_peer_id())
	vote_button.grab_focus()

func _clear_target_cards() -> void:
	if _target_grid != null:
		for child in _target_grid.get_children():
			child.queue_free()
	_target_buttons.clear()
	for viewport in _portrait_viewports:
		if is_instance_valid(viewport):
			viewport.queue_free()
	_portrait_viewports.clear()

func _valid_selected_target(local_peer_id: int) -> bool:
	if selected_peer_id <= 0 or selected_peer_id == local_peer_id:
		return false
	if not NetworkManager.peers.has(selected_peer_id):
		return false
	return MatchAuthority.is_peer_publicly_alive(selected_peer_id)

func _local_peer_id() -> int:
	return multiplayer.get_unique_id() if multiplayer.multiplayer_peer != null else 0

func _peer_name(peer_id: int) -> String:
	if peer_id <= 0:
		return "nadie"
	var data: Dictionary = NetworkManager.peers.get(peer_id, {})
	var name := str(data.get("display_name", ""))
	return name if not name.is_empty() else "Acólito %d" % peer_id
