extends CanvasLayer

signal presentation_started
signal presentation_finished

const CLIP_SECONDS := 10.0
const COVER_SECONDS := 0.35
const FADE_SECONDS := 0.7
const STREAMS := {
	PlayerState.Role.FAITHFUL: "res://assets/videos/roles/faithful.ogv",
	PlayerState.Role.HERETIC: "res://assets/videos/roles/heretic.ogv",
	PlayerState.Role.HEALER: "res://assets/videos/roles/priest.ogv",
	PlayerState.Role.INQUISITOR: "res://assets/videos/roles/inquisitor.ogv"
}
const FONT := preload("res://assets/fonts/Cinzel.ttf")
const ORNAMENT := preload("res://scripts/ui/role_reveal_ornament.gd")

@onready var panel: Control = $Panel
@onready var role_label: Label = $Panel/VBox/RoleLabel
@onready var description_label: Label = $Panel/VBox/DescriptionLabel
@onready var video: VideoStreamPlayer = $Panel/Aspect/Video
@onready var cover: ColorRect = $Panel/Cover
@onready var shade: TextureRect = $Panel/Aspect/Video/TitleShade
@onready var typography: Control = $Panel/VBox
var _glyph: Control
var _divider: Control
var _transition: Tween
var _generation := 0
var _presented_role := PlayerState.Role.UNASSIGNED
var _started_ms := 0
var _running := false
var _finishing := false
var _acknowledged := false


func _ready() -> void:
	panel.visible = false
	layer = 90
	video.bus = &"SFX"
	$Panel/Aspect.stretch_mode = AspectRatioContainer.STRETCH_FIT
	role_label.add_theme_font_override("font", FONT)
	description_label.add_theme_font_override("font", FONT)
	_glyph = ORNAMENT.new()
	_divider = ORNAMENT.new()
	typography.add_child(_glyph)
	typography.add_child(_divider)
	panel.resized.connect(_layout_typography)
	_layout_typography()
	MatchAuthority.phase_synced.connect(_on_phase_synced)
	MatchAuthority.private_role_received.connect(_on_private_role_received)
	MatchAuthority.private_heretic_teammate_received.connect(_on_private_heretic_teammate_received)
	video.finished.connect(_finish_presentation)
	if MatchAuthority.local_role != PlayerState.Role.UNASSIGNED:
		_show_local_role()


func _on_private_role_received(_role: int) -> void:
	_show_local_role()


func _on_private_heretic_teammate_received(_peer_id: int, _display_name: String) -> void:
	if MatchAuthority.local_role == PlayerState.Role.HERETIC:
		_update_copy()


func _on_phase_synced(phase: int) -> void:
	if phase != GameManager.MatchPhase.ROLE_REVEAL and not _acknowledged:
		_cancel_presentation()


func _show_local_role() -> void:
	if GameManager.phase != GameManager.MatchPhase.ROLE_REVEAL or not STREAMS.has(MatchAuthority.local_role):
		return
	_update_copy()
	if _running and _presented_role == MatchAuthority.local_role:
		return
	_cancel_presentation()
	_presented_role = MatchAuthority.local_role
	_running = true
	_finishing = false
	_acknowledged = false
	panel.show()
	presentation_started.emit()
	typography.hide()
	shade.hide()
	$Panel/BlackBackground.hide()
	cover.color.a = 0.0
	video.hide()
	_transition = create_tween()
	_transition.tween_property(cover, "color:a", 1.0, COVER_SECONDS)
	_transition.tween_callback(_begin_video.bind(_generation))


func _begin_video(generation: int) -> void:
	if generation != _generation or not _running:
		return
	_update_copy()
	var path: String = STREAMS[_presented_role]
	video.stream = load(path) as VideoStream if ResourceLoader.exists(path) else null
	_started_ms = Time.get_ticks_msec()
	$Panel/BlackBackground.show()
	typography.show()
	shade.show()
	video.show()
	if video.stream != null:
		video.play()
	_transition = create_tween()
	_transition.tween_property(cover, "color:a", 0.0, FADE_SECONDS)
	_transition.tween_interval(CLIP_SECONDS - FADE_SECONDS * 2.0)
	_transition.tween_property(cover, "color:a", 1.0, FADE_SECONDS)
	_transition.tween_callback(_finish_presentation)


func _process(_delta: float) -> void:
	# A decoder failure must not leave the player trapped on this screen.
	if _running and not _finishing and _started_ms > 0 and Time.get_ticks_msec() - _started_ms > 11500:
		_finish_presentation()


func _finish_presentation() -> void:
	if not _running or _finishing:
		return
	_finishing = true
	if _transition != null:
		_transition.kill()
	cover.color.a = 1.0
	video.stop()
	video.hide()
	typography.hide()
	shade.hide()
	$Panel/BlackBackground.hide()
	_acknowledged = true
	if GameManager.phase == GameManager.MatchPhase.ROLE_REVEAL:
		MatchAuthority.acknowledge_local_role()
	_transition = create_tween()
	_transition.tween_property(cover, "color:a", 0.0, COVER_SECONDS)
	_transition.tween_callback(_hide_completed)


func _hide_completed() -> void:
	panel.hide()
	_running = false
	_started_ms = 0
	presentation_finished.emit()


func _cancel_presentation() -> void:
	_generation += 1
	if _transition != null:
		_transition.kill()
	video.stop()
	panel.hide()
	_running = false
	_finishing = false
	_acknowledged = false
	_started_ms = 0


func _update_copy() -> void:
	role_label.add_theme_font_override("font", FONT)
	description_label.add_theme_font_override("font", FONT)
	var language := BotDirector.server_language
	role_label.text = RoleRevealCopy.title(MatchAuthority.local_role, language)
	description_label.text = RoleRevealCopy.description(MatchAuthority.local_role, language, MatchAuthority.local_heretic_teammate_name)
	var tint := RoleRevealCopy.tint(MatchAuthority.local_role)
	role_label.add_theme_color_override("font_color", tint)
	description_label.add_theme_color_override("font_color", tint.lightened(0.15))
	_glyph.configure(tint, MatchAuthority.local_role)
	_divider.configure(tint, MatchAuthority.local_role, true)


func _layout_typography() -> void:
	var dimensions := panel.size
	var scale_factor := dimensions.y / 1080.0
	role_label.position = Vector2(dimensions.x * 0.06, dimensions.y * 0.79)
	role_label.size = Vector2(dimensions.x * 0.88, dimensions.y * 0.105)
	role_label.add_theme_font_size_override("font_size", maxi(24, int(82 * scale_factor)))
	description_label.position = Vector2(dimensions.x * 0.08, dimensions.y * 0.925)
	description_label.size = Vector2(dimensions.x * 0.84, dimensions.y * 0.065)
	description_label.add_theme_font_size_override("font_size", maxi(12, int(21 * scale_factor)))
	_glyph.position = Vector2(dimensions.x * 0.5 - 64 * scale_factor, dimensions.y * 0.685)
	_glyph.size = Vector2(128, 100) * scale_factor
	_divider.position = Vector2(dimensions.x * 0.25, dimensions.y * 0.897)
	_divider.size = Vector2(dimensions.x * 0.5, 18 * scale_factor)
	_glyph.queue_redraw()
	_divider.queue_redraw()


func _exit_tree() -> void:
	if _transition != null:
		_transition.kill()


func blocks_gameplay_input() -> bool:
	return panel.visible
