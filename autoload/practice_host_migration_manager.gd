extends "res://autoload/host_migration_manager.gd"

# Host migration is explicitly out of the MVP. Keep the shared implementation
# available for future work, but do not bind its runtime hooks in production.
func _ready() -> void:
	pass

func _process(_delta: float) -> void:
	pass

func request_voluntary_host_exit() -> bool:
	voluntary_transfer_failed.emit("Host migration está desactivado en el MVP.")
	return false
