extends Control

var tint := Color.WHITE
var role := 1
var divider := false


func _draw() -> void:
	var center := size * 0.5
	var thickness := maxf(1.0, size.y / 50.0)
	if divider:
		draw_line(Vector2(0, center.y), Vector2(center.x - 16, center.y), tint.darkened(0.35), thickness)
		draw_line(Vector2(center.x + 16, center.y), Vector2(size.x, center.y), tint.darkened(0.35), thickness)
		var diamond := PackedVector2Array([center + Vector2(0, -5), center + Vector2(5, 0), center + Vector2(0, 5), center + Vector2(-5, 0), center + Vector2(0, -5)])
		draw_polyline(diamond, tint, thickness, true)
		return
	var radius := size.y * 0.23
	draw_arc(center, radius, 0, TAU, 64, tint, thickness * 1.2, true)
	draw_line(center - Vector2(0, size.y * 0.42), center + Vector2(0, size.y * 0.42), tint, thickness)
	draw_circle(center, thickness * 2.2, tint)
	if role == PlayerState.Role.HEALER:
		for index in range(8):
			var direction := Vector2.from_angle(index * TAU / 8.0)
			draw_line(center + direction * (radius + 5), center + direction * (radius + size.y * 0.12), tint, thickness)
	elif role == PlayerState.Role.HERETIC:
		for index in range(3):
			draw_circle(center + Vector2(0, radius + 9 + index * 6), thickness * 1.5, tint)


func configure(color: Color, role_value: int, is_divider: bool = false) -> void:
	tint = color
	role = role_value
	divider = is_divider
	queue_redraw()
