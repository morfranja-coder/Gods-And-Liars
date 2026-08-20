extends Control

@onready var status_label: Label = %StatusLabel

func _ready() -> void:
	GameManager.reset_match()
	status_label.text = "Gods & Liars — FASE 0\nCore bootstrap OK\nSteam: pending adapter integration"
