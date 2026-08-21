extends CanvasLayer

var selected_peer_id: int = 0
var _table: Node = null
var _submission_pending: bool = false
var _action_committed: bool = false
var _submitted_phase: int = -1

@onready var panel: PanelContainer = $Panel
@onready var phase_label: Label = $Panel/VBox/PhaseLabel
@onready var target_label: Label = $Panel/VBox/TargetLabel
@onready var confirm_button: Button = $Panel/VBox/ConfirmButton
@onready var result_label: Label = $Panel/VBox/ResultLabel

func _ready() -> void:
	_table = get_parent()
	if _table != null and _table.has_signal("target_selected"):
		_table.target_selected.connect(_on_target_selected)
	confirm_button.pressed.connect(_on_confirm_pressed)
	MatchAuthority.phase_synced.connect(_on_phase_synced)
	MatchAuthority.night_action_result_received.connect(_on_night_action_result_received)
	MatchAuthority.private_investigation_received.connect(_on_private_investigation_received)
	MatchAuthority.night_resolution_received.connect(_on_night_resolution_received)
	_refresh()

func _on_target_selected(peer_id: int) -> void:
	if _submission_pending or _action_committed:
		return
	selected_peer_id = peer_id
	_refresh()

func _on_phase_synced(_phase: int) -> void:
	selected_peer_id = 0
	_submission_pending = false
	_action_committed = false
	_submitted_phase = -1
	_refresh()

func _on_confirm_pressed() -> void:
	if not _valid_selected_target():
		result_label.text = "Objetivo inválido. Elegí otro."
		_refresh()
		return
	_submission_pending = true
	_submitted_phase = int(GameManager.phase)
	result_label.text = "Enviando acción al host..."
	MatchAuthority.submit_local_night_target(selected_peer_id)
	_refresh()

func _on_night_action_result_received(accepted: bool, target_peer_id: int) -> void:
	if _submitted_phase != int(GameManager.phase):
		return
	_submission_pending = false
	if accepted:
		_action_committed = true
		selected_peer_id = target_peer_id
		result_label.text = "Acción aceptada por el host."
	else:
		_action_committed = false
		selected_peer_id = 0
		result_label.text = "Objetivo inválido. Elegí otro."
	_refresh()

func _on_private_investigation_received(target_peer_id: int, is_heretic: bool) -> void:
	var name := _peer_name(target_peer_id)
	result_label.text = "%s ES HEREJE." % name if is_heretic else "%s NO es Hereje." % name

func _on_night_resolution_received(killed_peer_ids: Array[int]) -> void:
	if killed_peer_ids.is_empty():
		result_label.text = "La noche terminó sin víctimas."
	else:
		var names: PackedStringArray = []
		for peer_id in killed_peer_ids:
			names.append(_peer_name(int(peer_id)))
		result_label.text = "Víctimas de la noche: %s" % ", ".join(names)
	_refresh()

func _refresh() -> void:
	var required_role := NightPhaseRules.role_for_phase(GameManager.phase)
	var is_my_turn := required_role != PlayerState.Role.UNASSIGNED and required_role == MatchAuthority.local_role
	var local_peer_id := multiplayer.get_unique_id() if multiplayer.multiplayer_peer != null else 0
	var local_alive := local_peer_id == 0 or MatchAuthority.is_peer_publicly_alive(local_peer_id)
	panel.visible = (
		NightPhaseRules.is_action_phase(GameManager.phase)
		or GameManager.phase == GameManager.MatchPhase.NIGHT_RESOLUTION
	)
	phase_label.text = _phase_text()
	target_label.text = (
		"Objetivo: %s" % _peer_name(selected_peer_id)
		if selected_peer_id > 0
		else "Objetivo: ninguno"
	)
	confirm_button.visible = is_my_turn and local_alive
	confirm_button.disabled = (
		not is_my_turn
		or not local_alive
		or not _valid_selected_target()
		or _submission_pending
		or _action_committed
	)
	if not is_my_turn and NightPhaseRules.is_action_phase(GameManager.phase):
		target_label.text = "Esperando la acción de otro rol..."

func _valid_selected_target() -> bool:
	if selected_peer_id <= 0 or not MatchAuthority.is_peer_publicly_alive(selected_peer_id):
		return false
	var local_peer_id := multiplayer.get_unique_id() if multiplayer.multiplayer_peer != null else 0
	if MatchAuthority.local_role in [PlayerState.Role.HERETIC, PlayerState.Role.INQUISITOR]:
		return selected_peer_id != local_peer_id
	return true

func _phase_text() -> String:
	match GameManager.phase:
		GameManager.MatchPhase.HERETIC_ACTION:
			return "Noche — Los Herejes eligen"
		GameManager.MatchPhase.HEALER_ACTION:
			return "Noche — El Sanador protege"
		GameManager.MatchPhase.INQUISITOR_ACTION:
			return "Noche — El Inquisidor investiga"
		GameManager.MatchPhase.NIGHT_RESOLUTION:
			return "Noche — Resolución"
		_:
			return "Noche"

func _peer_name(peer_id: int) -> String:
	if peer_id <= 0:
		return "nadie"
	var data: Dictionary = NetworkManager.peers.get(peer_id, {})
	var name := str(data.get("display_name", ""))
	return name if not name.is_empty() else "Player %d" % peer_id
