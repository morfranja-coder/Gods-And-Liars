class_name PlayerColors
extends RefCounted

const COLORS := [
	Color("#8F2F28"),
	Color("#315F74"),
	Color("#55704A"),
	Color("#9A6C32"),
	Color("#66527D"),
	Color("#A58F6F"),
	Color("#3D7770"),
	Color("#6F7377"),
]

static func for_seat(seat_id: int) -> Color:
	if seat_id < 0:
		return Color.WHITE
	return COLORS[seat_id % COLORS.size()]
