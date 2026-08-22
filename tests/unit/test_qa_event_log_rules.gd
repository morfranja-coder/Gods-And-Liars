class_name QAEventLogRulesTest
extends GdUnitTestSuite

func test_client_label_is_sanitized_and_bounded() -> void:
	assert_str(QAEventLogRules.sanitize_client_label(" Host A!! ")).is_equal("hosta")
	assert_int(
		QAEventLogRules.sanitize_client_label("abcdefghijklmnopqrstuvwxyz1234567890").length()
	).is_equal(QAEventLogRules.MAX_CLIENT_LABEL_LENGTH)

func test_record_contains_context_event_and_deep_copied_payload() -> void:
	var payload := {"peer_id": 7, "nested": {"value": 1}}
	var context := {
		"monotonic_ms": 100,
		"unix_time": 200.0,
		"client": "host",
		"steam_id": 7001,
		"peer_id": 1,
		"lobby_id": 9001,
		"is_host": true,
		"phase": 8,
		"round": 2,
	}
	var record := QAEventLogRules.make_record(" vote_accepted ", payload, context)
	payload["nested"]["value"] = 9
	assert_str(record["event"]).is_equal("vote_accepted")
	assert_int(record["payload"]["nested"]["value"]).is_equal(1)
	assert_bool(QAEventLogRules.is_valid_record(record)).is_true()

func test_record_validation_rejects_missing_context_or_payload() -> void:
	var incomplete := {"event": "peer_joined", "payload": {}}
	assert_bool(QAEventLogRules.is_valid_record(incomplete)).is_false()
	var complete := {
		"monotonic_ms": 100,
		"unix_time": 200.0,
		"client": "client-b",
		"steam_id": 7002,
		"peer_id": 4,
		"lobby_id": 9001,
		"is_host": false,
		"phase": 8,
		"round": 2,
		"event": "peer_updated",
		"payload": [],
	}
	assert_bool(QAEventLogRules.is_valid_record(complete)).is_false()
