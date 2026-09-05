extends Control

const MAIN_MENU_SCENE := "res://scenes/main_menu/main_menu.tscn"
const TABLE_SCENE := "res://scenes/table/table.tscn"

@onready var status_label: Label = %StatusLabel

func _ready() -> void:
	GameManager.reset_match()
	status_label.text = "Gods & Liars\nInicializando ritual..."
	var forced_role := _practice_role_from_command_line()
	if forced_role != PlayerState.Role.UNASSIGNED:
		PracticeManager.start_seven_bot_match(forced_role)
		await get_tree().process_frame
		get_tree().change_scene_to_file(TABLE_SCENE)
		return
	await get_tree().process_frame
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func _practice_role_from_command_line() -> PlayerState.Role:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		args = OS.get_cmdline_args()
	for raw_arg in args:
		var role := PracticeManager.role_for_practice_command(str(raw_arg))
		if role != PlayerState.Role.UNASSIGNED:
			return role
	return PlayerState.Role.UNASSIGNED
