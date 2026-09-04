extends SceneTree

const PROBE_SCRIPT := preload("res://scripts/qa/qa_local_transport_probe.gd")
const DEFAULT_PORT := 24681
const TIMEOUT_SECONDS := 10.0
const SUCCESS_QUIT_DELAY_SECONDS := 0.25

var _probe: QALocalTransportProbe
var _elapsed := 0.0
var _role := ""
var _transport_started := false
var _completed := false
var _success_quit_delay := -1.0

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

func _process(delta: float) -> bool:
	if not _transport_started:
		_transport_started = true
		_start_transport()
		return false

	if _completed:
		_success_quit_delay -= delta
		if _success_quit_delay <= 0.0:
			quit(0)
		return false

	_elapsed += delta
	if _elapsed >= TIMEOUT_SECONDS:
		_fail("%s timed out" % _role)
	return false

func _start_transport() -> void:
	var error := OK
	if _role == "server":
		error = _probe.start_server(DEFAULT_PORT)
	else:
		error = _probe.start_client("127.0.0.1", DEFAULT_PORT)
	if error != OK:
		_fail("failed to start %s transport: %s" % [_role, error_string(error)])
		return
	print("D1 %s: started" % _role.to_upper())

func _on_completed(success: bool, message: String) -> void:
	if not success:
		_fail(message)
		return
	if _completed:
		return
	_completed = true
	_success_quit_delay = SUCCESS_QUIT_DELAY_SECONDS
	print("GREEN: Gate D1 %s - %s" % [_role, message])

func _fail(message: String) -> void:
	push_error("RED: Gate D1 %s - %s" % [_role, message])
	quit(1)
