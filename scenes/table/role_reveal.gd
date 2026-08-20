extends CanvasLayer

@onready var panel: Control = $Panel
@onready var role_label: Label = $Panel/VBox/RoleLabel
@onready var description_label: Label = $Panel/VBox/DescriptionLabel
@onready var close_button: Button = $Panel/VBox/CloseButton

func _ready() -> void:
	panel.visible = false
	close_button.pressed.connect(_on_close_pressed)
	MatchAuthority.private_role_received.connect(_on_private_role_received)
	if MatchAuthority.local_role != PlayerState.Role.UNASSIGNED:
		_show_role(int(MatchAuthority.local_role))

func _on_private_role_received(role: int) -> void:
	_show_role(role)

func _show_role(role: int) -> void:
	role_label.text = MatchAuthority.role_title(role)
	description_label.text = MatchAuthority.role_description(role)
	panel.visible = true

func _on_close_pressed() -> void:
	panel.visible = false
