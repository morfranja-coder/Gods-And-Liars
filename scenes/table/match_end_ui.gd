extends CanvasLayer

var _winner: StringName = &""

@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var state_label: Label = $Panel/VBox/StateLabel
@onready var rematch_button: Button = $Panel/VBox/RematchButton

func _ready() -> void:
	panel.visible = false
	rematch_button.pressed.connect(_on_rematch_pressed)
	MatchAuthority.match_end_received.connect(_on_match_end_received)
	MatchAuthority.rematch_received.connect(_on_rematch_received)
	if not MatchAuthority.public_winner.is_empty():
		_on_match_end_received(MatchAuthority.public_winner)

func _on_match_end_received(winner: StringName) -> void:
	_winner = winner
	panel.visible = true
	title_label.text = "VICTORIA DE LOS HEREJES" if winner == &"heretics" else "VICTORIA DE LOS FIELES"
	state_label.text = "Sos un espectro." if MatchAuthority.is_local_ghost() else "Sobreviviste al ritual."
	rematch_button.visible = multiplayer.is_server() and NetworkManager.is_host

func _on_rematch_pressed() -> void:
	if _winner.is_empty():
		return
	MatchAuthority.request_rematch()

func _on_rematch_received() -> void:
	_winner = &""
	panel.visible = false
