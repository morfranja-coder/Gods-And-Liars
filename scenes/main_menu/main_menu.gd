extends Control

const LOBBY_SCENE := "res://scenes/lobby/lobby.tscn"
const SETTINGS_SCENE := "res://scenes/settings/settings_menu.tscn"

@onready var enter_button: Button = %EnterButton
@onready var options_button: Button = %OptionsButton
@onready var quit_button: Button = %QuitButton

func _ready() -> void:
	enter_button.pressed.connect(_on_enter_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	enter_button.grab_focus()

func _on_enter_pressed() -> void:
	get_tree().change_scene_to_file(LOBBY_SCENE)

func _on_options_pressed() -> void:
	get_tree().root.set_meta("settings_return_scene", scene_file_path)
	get_tree().change_scene_to_file(SETTINGS_SCENE)

func _on_quit_pressed() -> void:
	get_tree().quit()
