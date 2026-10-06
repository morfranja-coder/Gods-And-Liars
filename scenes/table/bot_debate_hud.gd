extends CanvasLayer

var _log: RichTextLabel
var _entry: LineEdit
var _typing_label: Label
var _panel: PanelContainer


func _ready() -> void:
	layer = 28
	_panel = PanelContainer.new()
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 16
	_panel.offset_right = 520
	_panel.offset_top = -248
	_panel.offset_bottom = -16
	add_child(_panel)
	var box := VBoxContainer.new()
	_panel.add_child(box)
	_log = RichTextLabel.new()
	_log.custom_minimum_size = Vector2(490, 172)
	_log.scroll_following = true
	_log.add_theme_font_size_override("normal_font_size", 15)
	box.add_child(_log)
	_log.selection_enabled = true
	_typing_label = Label.new()
	_typing_label.add_theme_font_size_override("font_size", 13)
	box.add_child(_typing_label)
	BotDirector.typing_changed.connect(_on_typing_changed)
	_entry = LineEdit.new()
	_entry.placeholder_text = "Escribí para debatir con los bots"
	_entry.max_length = 320
	box.add_child(_entry)
	_entry.text_submitted.connect(_submit)
	_entry.focus_entered.connect(func(): InputBindings.text_entry_active = true)
	_entry.focus_exited.connect(func(): InputBindings.text_entry_active = false)
	BotDirector.utterance.connect(_on_utterance)
	MatchAuthority.phase_synced.connect(_on_phase)
	_on_phase(GameManager.phase)


func _on_phase(phase: int) -> void:
	_panel.visible = PracticeManager.active and phase == GameManager.MatchPhase.DAY_DISCUSSION
	if not _panel.visible:
		_entry.release_focus()
	else:
		_log.clear()
	_entry.editable = MatchAuthority.is_peer_publicly_alive(1)
	var placeholders := {
		"es": "Escribí para debatir con los bots", "en": "Type to debate with the bots", "pt": "Escreva para debater com os bots", "fr": "Écrivez pour débattre avec les bots"
	}
	_entry.placeholder_text = placeholders[BotDirector.server_language]


func _submit(text: String) -> void:
	BotDirector.submit_human_message(text)
	_entry.clear()
	_entry.release_focus()


func _on_utterance(id: int, text: String) -> void:
	var name_text: String = "Vos" if id == 1 else BotDirector.NAMES[(id - 2) % 7]
	_log.push_color(PlayerColors.for_seat(id - 1).lightened(0.35))
	_log.add_text(name_text + ": ")
	_log.pop()
	_log.add_text(text + "\n")


func _exit_tree() -> void:
	InputBindings.text_entry_active = false


func _on_typing_changed(id: int) -> void:
	if id == 0:
		_typing_label.text = ""
		return
	var formats := {"es": "%s está escribiendo…", "en": "%s is typing…", "pt": "%s está escrevendo…", "fr": "%s écrit…"}
	_typing_label.text = formats.get(BotDirector.server_language, formats.es) % BotDirector.public_name(id)
