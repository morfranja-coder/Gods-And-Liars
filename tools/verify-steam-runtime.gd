extends SceneTree

func _initialize() -> void:
	var missing: Array[String] = []
	if not Engine.has_singleton("Steam"):
		missing.append("Steam singleton")
	if not ClassDB.class_exists("SteamMultiplayerPeer"):
		missing.append("SteamMultiplayerPeer")
	if not missing.is_empty():
		printerr("RED: Steam runtime is incomplete: %s" % ", ".join(missing))
		quit(1)
		return
	print("GREEN: Steam runtime exposes Steam + SteamMultiplayerPeer")
	quit(0)
