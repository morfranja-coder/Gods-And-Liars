extends SceneTree

func _initialize() -> void:
	var missing: Array[String] = []
	if not Engine.has_singleton("Steam"):
		missing.append("Steam singleton")
	if not ClassDB.class_exists("SteamMultiplayerPeer"):
		missing.append("SteamMultiplayerPeer")
	else:
		var peer := ClassDB.instantiate("SteamMultiplayerPeer")
		if peer == null or not peer.has_method("get_steam64_from_peer_id"):
			missing.append("SteamMultiplayerPeer.get_steam64_from_peer_id")
	if not missing.is_empty():
		printerr("RED: Steam runtime is incomplete: %s" % ", ".join(missing))
		quit(1)
		return
	print("GREEN: Steam runtime exposes Steam + SteamMultiplayerPeer")
	quit(0)
