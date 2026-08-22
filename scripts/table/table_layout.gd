class_name TableLayout
extends RefCounted

const SEAT_COUNT := QuickMatchRules.TARGET_PLAYERS
const RADIUS_X := 4.8
const RADIUS_Z := 3.4

static func seat_position(seat_id: int) -> Vector3:
	assert(seat_id >= 0 and seat_id < SEAT_COUNT)
	var angle := -PI * 0.5 + TAU * float(seat_id) / float(SEAT_COUNT)
	return Vector3(cos(angle) * RADIUS_X, 0.0, sin(angle) * RADIUS_Z)

static func seat_rotation_y(seat_id: int) -> float:
	var position := seat_position(seat_id)
	return atan2(-position.x, -position.z)

static func seat_transform(seat_id: int) -> Transform3D:
	var basis := Basis(Vector3.UP, seat_rotation_y(seat_id))
	return Transform3D(basis, seat_position(seat_id))
