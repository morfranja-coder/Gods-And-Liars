extends "res://autoload/host_migration_manager.gd"

func _process(delta: float) -> void:
	if PracticeManager.active:
		return
	super._process(delta)
