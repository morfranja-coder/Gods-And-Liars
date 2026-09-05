extends CanvasLayer

const PLAYER_AVATAR_SCENE := preload(
	"res://scenes/player/player_avatar.tscn"
)

var selected_peer_id: int = 0

var _target_grid: GridContainer = null
var _target_center: CenterContainer = null

var _target_buttons: Dictionary = {}
var _portrait_viewports: Array[SubViewport] = []

var _discussion_timer: Label = null
var _turn_label: Label = null
var _live_votes_label: Label = null

@onready var panel: PanelContainer = $Panel
@onready var vbox: VBoxContainer = $Panel/VBox

@onready var phase_label: Label = $Panel/VBox/PhaseLabel
@onready var target_label: Label = $Panel/VBox/TargetLabel

@onready var begin_button: Button = (
	$Panel/VBox/BeginVotingButton
)

@onready var vote_button: Button = $Panel/VBox/VoteButton

@onready var result_label: Label = (
	$Panel/VBox/ResultLabel
)


func _ready() -> void:
	_build_discussion_timer()
	_build_turn_label()
	_build_live_votes()
	_build_target_grid()

	begin_button.visible = false
	vote_button.visible = false

	MatchAuthority.phase_synced.connect(
	_on_phase_synced
	)

	MatchAuthority.vote_state_synced.connect(
	_on_vote_state_synced
	)

	MatchAuthority.sacrifice_reveal_received.connect(
	_on_sacrifice_reveal_received
	)

	NetworkManager.peer_joined.connect(
	_on_roster_changed
	)

	NetworkManager.peer_left.connect(
	_on_roster_changed
	)

	NetworkManager.peer_updated.connect(
	_on_roster_changed
	)

	_refresh()


func _process(_delta: float) -> void:
	_refresh_discussion_timer()
	_refresh_vote_turn_timer()


func _build_discussion_timer() -> void:
	_discussion_timer = Label.new()
	_discussion_timer.name = "DiscussionTimer"

	_discussion_timer.anchor_left = 0.5
	_discussion_timer.anchor_right = 0.5

	_discussion_timer.offset_left = -150.0
	_discussion_timer.offset_right = 150.0
	_discussion_timer.offset_top = 26.0
	_discussion_timer.offset_bottom = 65.0

	_discussion_timer.horizontal_alignment = (
	HORIZONTAL_ALIGNMENT_CENTER
	)

	_discussion_timer.add_theme_font_size_override(
	"font_size",
	24
	)

	_discussion_timer.add_theme_color_override(
	"font_outline_color",
	Color(0, 0, 0, 1)
	)

	_discussion_timer.add_theme_constant_override(
	"outline_size",
	6
	)

	add_child(_discussion_timer)


func _build_turn_label() -> void:
	_turn_label = Label.new()
	_turn_label.name = "VoteTurnLabel"

	_turn_label.horizontal_alignment = (
	HORIZONTAL_ALIGNMENT_CENTER
	)

	_turn_label.add_theme_font_size_override(
	"font_size",
	20
	)

	vbox.add_child(_turn_label)
	vbox.move_child(_turn_label, 1)


func _build_live_votes() -> void:
	_live_votes_label = Label.new()
	_live_votes_label.name = "LiveVotes"

	_live_votes_label.horizontal_alignment = (
	HORIZONTAL_ALIGNMENT_LEFT
	)

	_live_votes_label.autowrap_mode = (
	TextServer.AUTOWRAP_WORD_SMART
	)

	_live_votes_label.add_theme_font_size_override(
	"font_size",
	16
	)

	vbox.add_child(_live_votes_label)


func _build_target_grid() -> void:
	_target_center = CenterContainer.new()
	_target_center.name = "TargetCenter"

	_target_center.size_flags_horizontal = (
	Control.SIZE_EXPAND_FILL
	)

	_target_grid = GridContainer.new()
	_target_grid.name = "TargetGrid"
	_target_grid.columns = 4

	_target_grid.add_theme_constant_override(
	"h_separation",
	14
	)

	_target_grid.add_theme_constant_override(
	"v_separation",
	14
	)

	_target_center.add_child(_target_grid)
	vbox.add_child(_target_center)


func _on_phase_synced(_phase: int) -> void:
	selected_peer_id = 0
	result_label.text = ""

	if GameManager.phase == GameManager.MatchPhase.VOTING:
		_rebuild_target_cards()
	else:
		_clear_target_cards()

	_refresh()


func _on_vote_state_synced(
	_votes: Dictionary,
	_current_voter_peer_id: int
	) -> void:
	selected_peer_id = 0

	_refresh()
	_refresh_live_vote_table()

	if _local_can_vote_now():
		call_deferred("_focus_first_vote_card")


func _on_roster_changed(_peer_id: int) -> void:
	if GameManager.phase == GameManager.MatchPhase.VOTING:
		_rebuild_target_cards()

	_refresh()


func _refresh_discussion_timer() -> void:
	if _discussion_timer == null:
		return

	var is_discussion: bool = (
	GameManager.phase
	== GameManager.MatchPhase.DAY_DISCUSSION
	)

	_discussion_timer.visible = is_discussion

	if not is_discussion:
		_discussion_timer.text = ""
		return

	var seconds: int = (
	MatchAuthority.phase_seconds_remaining()
	)

	_discussion_timer.text = (
	"DEBATE • %02d:%02d"
	% [seconds / 60, seconds % 60]
	)


func _refresh_vote_turn_timer() -> void:
	if GameManager.phase != GameManager.MatchPhase.VOTING:
		return

	if _turn_label == null:
		return

	var voter_peer_id: int = (
	MatchAuthority.current_voter_peer_id
	)

	if voter_peer_id <= 0:
		_turn_label.text = "Cerrando votación..."
		return

	var seconds: int = (
	MatchAuthority.vote_turn_seconds_remaining()
	)

	_turn_label.text = (
	"TURNO DE %s • %d s"
	% [
	_peer_name(voter_peer_id),
	seconds,
	]
	)


func _refresh() -> void:
	var is_voting: bool = (
	GameManager.phase
	== GameManager.MatchPhase.VOTING
	)

	var is_sacrifice: bool = (
	GameManager.phase
	== GameManager.MatchPhase.SACRIFICE
	)

	panel.visible = is_voting or is_sacrifice

	if not panel.visible:
		return

	phase_label.text = "DÍA %d" % GameManager.round_number

	if _turn_label != null:
		_turn_label.visible = is_voting

	if _live_votes_label != null:
		_live_votes_label.visible = is_voting

	var can_vote_now: bool = _local_can_vote_now()

	if _target_center != null:
		_target_center.visible = (
		is_voting
		and can_vote_now
		)

	if is_voting:
		if can_vote_now:
			target_label.text = (
			"WASD Elegir • ESPACIO Votar"
			)
		else:
			target_label.text = (
			"Observá la votación en vivo"
			)

		_refresh_live_vote_table()

	if is_sacrifice:
		target_label.text = ""

		if _turn_label != null:
			_turn_label.visible = false

		if _live_votes_label != null:
			_live_votes_label.visible = false


func _local_can_vote_now() -> bool:
	if multiplayer.multiplayer_peer == null:
		return false

	if MatchAuthority.is_local_ghost():
		return false

	var local_peer_id: int = (
	multiplayer.get_unique_id()
	)

	if not MatchAuthority.is_peer_publicly_alive(
	local_peer_id
	):
		return false

	return (
	local_peer_id
	== MatchAuthority.current_voter_peer_id
	)


func _rebuild_target_cards() -> void:
	_clear_target_cards()

	var local_peer_id: int = _local_peer_id()

	var peer_ids: Array = NetworkManager.peers.keys()

	peer_ids.sort_custom(
	func(a: Variant, b: Variant) -> bool:
		var data_a: Dictionary = (
		NetworkManager.peers[a]
		)

		var data_b: Dictionary = (
		NetworkManager.peers[b]
		)

		return (
		int(data_a.get("seat_id", 99))
		<
		int(data_b.get("seat_id", 99))
		)
	)

	for raw_peer_id in peer_ids:
		var peer_id: int = int(raw_peer_id)

		if peer_id == local_peer_id:
			continue

		_add_target_card(peer_id)

	if _local_can_vote_now():
		call_deferred("_focus_first_vote_card")


func _add_target_card(peer_id: int) -> void:
	var data: Dictionary = (
	NetworkManager.peers.get(peer_id, {})
	)

	var seat_id: int = int(
	data.get("seat_id", 0)
	)

	var player_color: Color = (
	PlayerColors.for_seat(seat_id)
	)

	var alive: bool = (
	MatchAuthority.is_peer_publicly_alive(peer_id)
	)

	var card := VBoxContainer.new()

	card.custom_minimum_size = Vector2(
	145,
	175
	)

	var button := Button.new()

	button.custom_minimum_size = Vector2(
	140,
	130
	)

	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE

	button.toggle_mode = true
	button.expand_icon = true

	button.disabled = not alive
	button.tooltip_text = _peer_name(peer_id)

	button.icon = _create_portrait(
	player_color
	)

	button.pressed.connect(
	_select_target.bind(peer_id)
	)

	button.focus_entered.connect(
	_focus_target.bind(peer_id)
	)

	if not alive:
		button.modulate = Color(
		1.0,
		0.25,
		0.25,
		0.58
		)

	card.add_child(button)

	var label := Label.new()

	label.text = (
	_peer_name(peer_id)
	if alive
	else "%s — MUERTO" % _peer_name(peer_id)
	)

	label.horizontal_alignment = (
	HORIZONTAL_ALIGNMENT_CENTER
	)

	label.add_theme_color_override(
	"font_color",
	player_color
	if alive
	else Color(0.8, 0.22, 0.22, 1.0)
	)

	card.add_child(label)

	_target_grid.add_child(card)

	_target_buttons[peer_id] = button


func _focus_target(peer_id: int) -> void:
	if not _local_can_vote_now():
		return

	if not MatchAuthority.is_peer_publicly_alive(peer_id):
		return

	selected_peer_id = peer_id

	for raw_id in _target_buttons.keys():
		var button: Button = (
		_target_buttons[raw_id] as Button
		)

		if button != null:
			button.button_pressed = (
			int(raw_id) == selected_peer_id
			)


func _select_target(peer_id: int) -> void:
	if not _local_can_vote_now():
		return

	if not MatchAuthority.is_peer_publicly_alive(peer_id):
		return

	selected_peer_id = peer_id

	MatchAuthority.submit_local_vote(
	selected_peer_id
	)

	result_label.text = (
	"Votaste a %s."
	% _peer_name(peer_id)
	)


func _focus_first_vote_card() -> void:
	for raw_peer_id in _target_buttons.keys():
		var button: Button = (
		_target_buttons[raw_peer_id] as Button
		)

		if button != null and not button.disabled:
			button.grab_focus()
			return


func _refresh_live_vote_table() -> void:
	if _live_votes_label == null:
		return

	var votes: Dictionary = (
	MatchAuthority.public_votes
	)

	var lines: Array[String] = []

	lines.append("VOTACIÓN EN VIVO")
	lines.append("")

	if votes.is_empty():
		lines.append("Todavía nadie votó.")
	else:
		for raw_voter_id in votes.keys():
			var voter_id: int = int(raw_voter_id)
			var target_id: int = int(votes[raw_voter_id])

			lines.append(
			"%s → %s"
			% [
			_peer_name(voter_id),
			_peer_name(target_id),
			]
			)

	var tally: Dictionary = {}

	for raw_target_id in votes.values():
		var target_id: int = int(raw_target_id)

		tally[target_id] = (
		int(tally.get(target_id, 0))
		+ 1
		)

	lines.append("")
	lines.append("RECUENTO")

	if tally.is_empty():
		lines.append("—")
	else:
		var targets: Array = tally.keys()

		targets.sort_custom(
		func(a: Variant, b: Variant) -> bool:
			return (
			int(tally[a])
			>
			int(tally[b])
			)
		)

		for raw_target_id in targets:
			var target_id: int = int(raw_target_id)

			lines.append(
			"%s → %d"
			% [
			_peer_name(target_id),
			int(tally[target_id]),
			]
			)

	_live_votes_label.text = "\n".join(lines)


func _on_sacrifice_reveal_received(
	sacrificed_peer_id: int,
	_tied: bool,
	was_heretic: bool
	) -> void:
	if sacrificed_peer_id <= 0:
		result_label.text = (
		"El juicio terminó sin sacrificio."
		)
		return

	result_label.text = (
	"Se sacrificó a un Hereje."
	if was_heretic
	else "Se sacrificó a un inocente."
	)


func _create_portrait(
	player_color: Color
	) -> Texture2D:
	var viewport := SubViewport.new()

	viewport.size = Vector2i(192, 160)
	viewport.transparent_bg = true
	viewport.own_world_3d = true

	viewport.render_target_update_mode = (
	SubViewport.UPDATE_ALWAYS
	)

	add_child(viewport)

	_portrait_viewports.append(viewport)

	var avatar := (
	PLAYER_AVATAR_SCENE.instantiate()
	as Node3D
	)

	viewport.add_child(avatar)

	if avatar is AvatarSlots:
		(avatar as AvatarSlots).set_player_color(
		player_color
		)

	var name_label := (
	avatar.get_node_or_null("NameLabel")
	as Label3D
	)

	if name_label != null:
		name_label.visible = false

	var light := DirectionalLight3D.new()

	light.rotation_degrees = Vector3(
	-35.0,
	-25.0,
	0.0
	)

	light.light_energy = 2.0

	viewport.add_child(light)

	var camera := Camera3D.new()
	camera.fov = 34.0

	viewport.add_child(camera)

	camera.position = Vector3(
	0.0,
	1.25,
	3.2
	)

	camera.look_at(
	Vector3(0.0, 1.2, 0.0),
	Vector3.UP
	)

	camera.current = true

	return viewport.get_texture()


func _clear_target_cards() -> void:
	if _target_grid != null:
		for child in _target_grid.get_children():
			child.queue_free()

	_target_buttons.clear()

	for viewport in _portrait_viewports:
		if is_instance_valid(viewport):
			viewport.queue_free()

	_portrait_viewports.clear()


func blocks_gameplay_input() -> bool:
	return (
	GameManager.phase
	== GameManager.MatchPhase.VOTING
	)


func _local_peer_id() -> int:
	if multiplayer.multiplayer_peer == null:
		return 0

	return multiplayer.get_unique_id()


func _peer_name(peer_id: int) -> String:
	if peer_id <= 0:
		return "nadie"

	var data: Dictionary = (
	NetworkManager.peers.get(peer_id, {})
	)

	var display_name: String = str(
	data.get("display_name", "")
	)

	if display_name.is_empty():
		return "Acólito %d" % peer_id

	return display_name
