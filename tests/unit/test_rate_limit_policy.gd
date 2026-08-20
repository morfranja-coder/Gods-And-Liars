class_name RateLimitPolicyTest
extends GdUnitTestSuite

func test_first_request_is_allowed() -> void:
	assert_bool(RateLimitPolicy.can_accept(0, 1000)).is_true()

func test_request_inside_interval_is_rejected() -> void:
	assert_bool(RateLimitPolicy.can_accept(1000, 1050, 100)).is_false()

func test_request_at_interval_boundary_is_allowed() -> void:
	assert_bool(RateLimitPolicy.can_accept(1000, 1100, 100)).is_true()

func test_invalid_time_is_rejected() -> void:
	assert_bool(RateLimitPolicy.can_accept(-1, 1000)).is_false()
