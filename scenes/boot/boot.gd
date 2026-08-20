extends Control

@onready var status_label: Label = %StatusLabel

func _ready() -> void:
	GameManager.reset_match()
	status_label.text = "Gods & Liars\nInicializando ritual..."
	await get_tree().process_frame
	get_tree().change_scene_to_file("res://scenes/lobby/lobby.tscn")
