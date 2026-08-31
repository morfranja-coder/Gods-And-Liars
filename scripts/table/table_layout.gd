class_name TableLayout
extends RefCounted

const SEAT_COUNT := QuickMatchRules.TARGET_PLAYERS
const SCENARIO_CENTER := Vector3(0.0, 0.0, -2.0)
const SCENARIO_RADIUS := 5.35
const SEAT_ANGLES_DEGREES := [210.0, 190.0, 165.0, 140.0, 40.0, 15.0, -10.0, -30.0]

static func seat_position(seat_id: int) -> Vector3:
	assert(seat_id >= 0 and seat_id < SEAT_COUNT)
	var angle := deg_to_rad(SEAT_ANGLES_DEGREES[seat_id])
	return SCENARIO_CENTER + Vector3(
		sin(angle) * SCENARIO_RADIUS,
		0.0,
		cos(angle) * SCENARIO_RADIUS
	)

static func seat_rotation_y(seat_id: int) -> float:
	var position := seat_position(seat_id)
	return atan2(-position.x, -position.z)

static func seat_transform(seat_id: int) -> Transform3D:
	var basis := Basis(Vector3.UP, seat_rotation_y(seat_id))
	return Transform3D(basis, seat_position(seat_id))
