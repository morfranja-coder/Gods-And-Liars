extends Control

const LOBBY_SCENE := "res://scenes/lobby/lobby.tscn"

@onready var enter_button: Button = %EnterButton
@onready var quit_button: Button = %QuitButton

func _ready() -> void:
	enter_button.pressed.connect(_on_enter_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	enter_button.grab_focus()

func _on_enter_pressed() -> void:
	get_tree().change_scene_to_file(LOBBY_SCENE)

func _on_quit_pressed() -> void:
	get_tree().quit()
