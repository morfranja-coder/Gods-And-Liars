class_name GhostHUD
extends CanvasLayer

@onready var state_label: Label = %StateLabel

func show_ghost_mode(is_heretic: bool) -> void:
	visible = true
	state_label.text = "ESPECTRO HEREJE" if is_heretic else "ESPECTRO FIEL"

func hide_ghost_mode() -> void:
	visible = false
