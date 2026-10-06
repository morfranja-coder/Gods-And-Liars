extends Control

const LOBBY_SCENE := "res://scenes/lobby/lobby.tscn"
const SETTINGS_SCENE := "res://scenes/settings/settings_menu.tscn"
const TABLE_SCENE := "res://scenes/table/table.tscn"

@onready var enter_button: Button = %EnterButton
@onready var practice_button: Button = %PracticeButton
@onready var options_button: Button = %OptionsButton
@onready var quit_button: Button = %QuitButton

func _ready() -> void:
	var art := TextureRect.new()
	art.name = "RitualMenuArtwork"
	art.texture = load("res://assets/ui/main_menu_background.png")
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	move_child(art, 1)
	$TopGlow.visible = false
	$Center.anchor_right = 0.70
	var hud = load("res://ui/ritual_hud_theme.gd")
	hud.apply_tree($Center)
	var title: Label = $Center/VBox/Title
	var logo := TextureRect.new()
	logo.name = "GameLogo"
	logo.texture = load("res://assets/ui/game_logo.png")
	logo.custom_minimum_size = Vector2(0, 100)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.tooltip_text = title.text
	$Center/VBox.add_child(logo)
	$Center/VBox.move_child(logo, title.get_index())
	title.visible = false
	$Center/VBox/Eyebrow.add_theme_font_override("font", hud.heading_font())
	enter_button.pressed.connect(_on_enter_pressed)
	practice_button.pressed.connect(_on_practice_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	enter_button.grab_focus()

func _on_enter_pressed() -> void:
	PracticeManager.stop_practice()
	get_tree().change_scene_to_file(LOBBY_SCENE)

func _on_practice_pressed() -> void:
	PracticeManager.start_seven_bot_match()
	get_tree().change_scene_to_file(TABLE_SCENE)

func _on_options_pressed() -> void:
	get_tree().root.set_meta("settings_return_scene", scene_file_path)
	get_tree().change_scene_to_file(SETTINGS_SCENE)

func _on_quit_pressed() -> void:
	get_tree().quit()
