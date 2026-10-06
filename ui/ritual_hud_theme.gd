extends RefCounted

const GOLD := Color(0.64, 0.49, 0.28)
const IVORY := Color(0.94, 0.90, 0.81)
const HEADING_FONT := preload("res://assets/fonts/Cinzel.ttf")
const BODY_FONT := preload("res://assets/fonts/BarlowSemiCondensed-Regular.ttf")
const STRONG_FONT := preload("res://assets/fonts/BarlowSemiCondensed-SemiBold.ttf")

static func heading_font() -> Font:
	return HEADING_FONT

static func body_font() -> Font:
	return BODY_FONT

static func strong_font() -> Font:
	return STRONG_FONT

static func panel_style(padding: float = 14.0) -> StyleBox:
	var style := StyleBoxTexture.new()
	style.texture = load("res://assets/ui/ritual_panel.png")
	style.texture_margin_left = 37
	style.texture_margin_right = 37
	style.texture_margin_top = 37
	style.texture_margin_bottom = 37
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

static func flat_style(color: Color = GOLD, background: Color = Color(0.025, 0.022, 0.02, 0.90)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = color
	style.set_border_width_all(1)
	style.set_content_margin_all(10)
	style.set_corner_radius_all(2)
	return style

static func apply_tree(node: Node) -> void:
	if node is PanelContainer:
		node.add_theme_stylebox_override("panel", panel_style())
	if node is Button or node is LineEdit:
		node.add_theme_font_override("font", body_font())
		node.add_theme_stylebox_override("normal", flat_style(GOLD.darkened(0.25)))
		node.add_theme_stylebox_override("focus", flat_style(IVORY, Color(0.09, 0.065, 0.035, 0.95)))
		node.add_theme_color_override("font_color", IVORY)
		if node is Button:
			node.add_theme_stylebox_override("hover", flat_style(GOLD.lightened(0.3), Color(0.12, 0.085, 0.04, 0.96)))
			node.add_theme_stylebox_override("pressed", flat_style(GOLD, Color(0.07, 0.04, 0.02, 0.96)))
			node.add_theme_font_override("font", heading_font())
	if node is Label:
		node.add_theme_font_override("font", body_font())
		node.add_theme_color_override("font_color", IVORY)
		if "Phase" in node.name or "Title" in node.name:
			node.add_theme_font_override("font", heading_font())
	if node is RichTextLabel:
		node.add_theme_font_override("normal_font", body_font())
		node.add_theme_font_override("bold_font", strong_font())
		node.add_theme_color_override("default_color", IVORY)
	for child in node.get_children():
		apply_tree(child)
