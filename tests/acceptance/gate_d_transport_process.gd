extends SceneTree

const PROBE_SCRIPT := preload("res://scripts/qa/qa_local_transport_probe.gd")
const DEFAULT_PORT := 24681
const TIMEOUT_SECONDS := 10.0

var _probe: QALocalTransportProbe
var _elapsed := 0.0
var _role := ""

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		_fail("missing role argument")
		return
	_role = str(args[0]).strip_edges().to_lower()
	if _role not in ["server", "client"]:
		_fail("role must be server or client")
		return

	_probe = PROBE_SCRIPT.new()
	get_root().add_child(_probe)
	_probe.completed.connect(_on_completed)

	var error := OK
	if _role == "server":
		error = _probe.start_server(DEFAULT_PORT)
	else:
		error = _probe.start_client("127.0.0.1", DEFAULT_PORT)
	if error != OK:
		_fail("failed to start %s transport: %s" % [_role, error_string(error)])
		return
	print("D1 %s: started" % _role.to_upper())

func _process(delta: float) -> bool:
	_elapsed += delta
	if _elapsed >= TIMEOUT_SECONDS:
		_fail("%s timed out" % _role)
	return false

func _on_completed(success: bool, message: String) -> void:
	if not success:
		_fail(message)
		return
	print("GREEN: Gate D1 %s - %s" % [_role, message])
	quit(0)

func _fail(message: String) -> void:
	push_error("RED: Gate D1 %s - %s" % [_role, message])
	quit(1)
