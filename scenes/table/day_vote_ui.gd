extends CanvasLayer

var selected_peer_id: int = 0
var _table: Node = null

@onready var panel: PanelContainer = $Panel
@onready var phase_label: Label = $Panel/VBox/PhaseLabel
@onready var target_label: Label = $Panel/VBox/TargetLabel
@onready var begin_button: Button = $Panel/VBox/BeginVotingButton
@onready var vote_button: Button = $Panel/VBox/VoteButton
@onready var result_label: Label = $Panel/VBox/ResultLabel

func _ready() -> void:
	_table = get_parent()
	if _table != null and _table.has_signal("target_selected"):
		_table.target_selected.connect(_on_target_selected)
	begin_button.pressed.connect(_on_begin_voting_pressed)
	vote_button.pressed.connect(_on_vote_pressed)
	MatchAuthority.phase_synced.connect(_on_phase_synced)
	MatchAuthority.vote_resolution_received.connect(_on_vote_resolution_received)
	_refresh()

func _on_target_selected(peer_id: int) -> void:
	selected_peer_id = peer_id
	_refresh()

func _on_phase_synced(_phase: int) -> void:
	selected_peer_id = 0
	_refresh()

func _on_begin_voting_pressed() -> void:
	MatchAuthority.request_begin_voting()

func _on_vote_pressed() -> void:
	var local_peer_id := multiplayer.get_unique_id() if multiplayer.multiplayer_peer != null else 0
	if not _valid_selected_target(local_peer_id):
		result_label.text = "Voto inválido. Elegí a otro jugador vivo."
		_refresh()
		return
	MatchAuthority.submit_local_vote(selected_peer_id)
	result_label.text = "Voto enviado. Podés cambiarlo hasta que cierre la votación."
	_refresh()

func _on_vote_resolution_received(sacrificed_peer_id: int, tied: bool) -> void:
	if tied:
		result_label.text = "Empate. Nadie fue sacrificado."
	else:
		result_label.text = "%s fue sacrificado." % _peer_name(sacrificed_peer_id)
	_refresh()

func _refresh() -> void:
	var is_discussion := GameManager.phase == GameManager.MatchPhase.DAY_DISCUSSION
	var is_voting := GameManager.phase == GameManager.MatchPhase.VOTING
	var is_sacrifice := GameManager.phase in [
		GameManager.MatchPhase.SACRIFICE,
		GameManager.MatchPhase.WIN_CHECK,
	]
	panel.visible = is_discussion or is_voting or is_sacrifice
	phase_label.text = "Día — Discusión" if is_discussion else "Día — Votación"
	begin_button.visible = is_discussion and multiplayer.is_server() and NetworkManager.is_host
	var local_peer_id := multiplayer.get_unique_id() if multiplayer.multiplayer_peer != null else 0
	var local_alive := local_peer_id > 0 and MatchAuthority.is_peer_publicly_alive(local_peer_id)
	vote_button.visible = is_voting and local_alive
	vote_button.disabled = not is_voting or not local_alive or not _valid_selected_target(local_peer_id)
	target_label.visible = is_voting
	target_label.text = (
		"Acusado: %s" % _peer_name(selected_peer_id)
		if selected_peer_id > 0
		else "Acusado: ninguno"
	)
	_focus_active_button()

func _focus_active_button() -> void:
	if begin_button.visible and not begin_button.disabled:
		begin_button.grab_focus()
	elif vote_button.visible and not vote_button.disabled:
		vote_button.grab_focus()

func _valid_selected_target(local_peer_id: int) -> bool:
	if selected_peer_id <= 0 or selected_peer_id == local_peer_id:
		return false
	if not NetworkManager.peers.has(selected_peer_id):
		return false
	return MatchAuthority.is_peer_publicly_alive(selected_peer_id)

func _peer_name(peer_id: int) -> String:
	if peer_id <= 0:
		return "nadie"
	var data: Dictionary = NetworkManager.peers.get(peer_id, {})
	var name := str(data.get("display_name", ""))
	return name if not name.is_empty() else "Player %d" % peer_id
