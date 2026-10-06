extends CanvasLayer

@onready var panel: Control = $Panel
@onready var role_label: Label = $Panel/VBox/RoleLabel
@onready var description_label: Label = $Panel/VBox/DescriptionLabel
@onready var close_button: Button = $Panel/VBox/CloseButton

func _ready() -> void:
	panel.visible = false
	MatchAuthority.phase_synced.connect(_on_phase_synced)
	close_button.pressed.connect(_on_close_pressed)
	MatchAuthority.private_role_received.connect(_on_private_role_received)
	MatchAuthority.private_heretic_teammate_received.connect(_on_private_heretic_teammate_received)
	if MatchAuthority.local_role != PlayerState.Role.UNASSIGNED:
		_show_local_role()

func _on_private_role_received(_role: int) -> void:
	_show_local_role()

func _on_private_heretic_teammate_received(_peer_id: int, _display_name: String) -> void:
	if MatchAuthority.local_role == PlayerState.Role.HERETIC:
		_show_local_role()

func _on_phase_synced(phase: int) -> void:
	if phase != GameManager.MatchPhase.ROLE_REVEAL:
		panel.visible = false

func _show_local_role() -> void:
	if GameManager.phase != GameManager.MatchPhase.ROLE_REVEAL:
		return
	role_label.text = MatchAuthority.role_title()
	description_label.text = MatchAuthority.role_description()
	panel.visible = true
	close_button.grab_focus()

func _on_close_pressed() -> void:
	panel.visible = false
	MatchAuthority.acknowledge_local_role()
