extends SceneTree

const SEED_COUNT := 1000
const EXPECTED_PLAYERS := 8
const MIN_FAULT_COVERAGE := 500

var _failures: Array[String] = []

func _init() -> void:
	_run_gate()
	if _failures.is_empty():
		print(
			"GREEN: Gate B adversarial stress passed (%d seeds per fault)."
			% SEED_COUNT
		)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("RED: Gate B adversarial stress failed with %d issue(s)." % _failures.size())
	quit(1)

func _run_gate() -> void:
	_verify_fault(QAAdversarialSimulator.Fault.AFK_NIGHT, "afk_night", 10000)
	_verify_fault(QAAdversarialSimulator.Fault.INVALID_VOTE, "invalid_vote", 20000)
	_verify_fault(QAAdversarialSimulator.Fault.DUPLICATE_VOTE, "duplicate_vote", 30000)
	_verify_fault(
		QAAdversarialSimulator.Fault.DISCONNECT_AFTER_NIGHT,
		"disconnect_after_night",
		40000,
	)

func _verify_fault(fault: QAAdversarialSimulator.Fault, label: String, seed_offset: int) -> void:
	var consumed_count := 0
	for index in range(SEED_COUNT):
		var seed_value := seed_offset + index + 1
		var result := QAAdversarialSimulator.run(seed_value, fault, 0)
		if bool(result.get("fault_consumed", false)):
			consumed_count += 1
		_verify_result(label, seed_value, result)
	if consumed_count < MIN_FAULT_COVERAGE:
		_fail(
			"%s: fault consumed in only %d/%d seeds"
			% [label, consumed_count, SEED_COUNT]
		)

func _verify_result(label: String, seed_value: int, result: Dictionary) -> void:
	if bool(result.get("blocked", true)):
		_fail("%s seed %d: simulation blocked: %s" % [label, seed_value, result])
		return
	if not bool(result.get("completed", false)):
		_fail("%s seed %d: simulation did not complete: %s" % [label, seed_value, result])
		return
	if int(result.get("players", 0)) != EXPECTED_PLAYERS:
		_fail("%s seed %d: wrong player count: %s" % [label, seed_value, result])
	var winner := str(result.get("winner", ""))
	if winner not in ["faithful", "heretics"]:
		_fail("%s seed %d: invalid winner '%s'" % [label, seed_value, winner])
	var rounds := int(result.get("rounds", QAAdversarialSimulator.DEFAULT_MAX_ROUNDS + 1))
	if rounds <= 0 or rounds > QAAdversarialSimulator.DEFAULT_MAX_ROUNDS:
		_fail("%s seed %d: invalid round count %d" % [label, seed_value, rounds])
	var living := int(result.get("living", -1))
	if living < 0 or living > EXPECTED_PLAYERS:
		_fail("%s seed %d: invalid living count %d" % [label, seed_value, living])

func _fail(message: String) -> void:
	if _failures.size() < 100:
		_failures.append(message)
