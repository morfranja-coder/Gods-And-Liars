extends Node

signal private_role_received(role: int)
signal role_reveal_failed(reason: String)

var local_role: PlayerState.Role = PlayerState.Role.UNASSIGNED
var _session: MatchSession = null
var _roles_dispatched: bool = false

func reset() -> void:
	local_role = PlayerState.Role.UNASSIGNED
	_session = null
	_roles_dispatched = false

func begin_role_reveal() -> bool:
	if not multiplayer.is_server() or not NetworkManager.is_host:
		return false
	if _roles_dispatched:
		return false
	var session := _build_session(NetworkManager.peers)
	if session == null or not session.prepare_match():
		role_reveal_failed.emit("Se necesitan al menos %d jugadores para repartir roles." % MatchSession.MIN_PLAYERS)
		return false
	_session = session
	_roles_dispatched = true
	GameManager.start_match()
	_dispatch_private_roles()
	return true

func server_role_for_peer(peer_id: int) -> PlayerState.Role:
	if not multiplayer.is_server() or _session == null:
		return PlayerState.Role.UNASSIGNED
	var player := _session.get_player(peer_id)
	return PlayerState.Role.UNASSIGNED if player == null else player.role

func role_title(role: PlayerState.Role = local_role) -> String:
	match role:
		PlayerState.Role.FAITHFUL:
			return "Fiel"
		PlayerState.Role.HERETIC:
			return "Hereje"
		PlayerState.Role.HEALER:
			return "Sanador"
		PlayerState.Role.INQUISITOR:
			return "Inquisidor"
		_:
			return "Sin revelar"

func role_description(role: PlayerState.Role = local_role) -> String:
	match role:
		PlayerState.Role.FAITHFUL:
			return "Descubrí a los herejes y sobreviví al ritual."
		PlayerState.Role.HERETIC:
			return "Eliminá a los fieles sin revelar tu identidad."
		PlayerState.Role.HEALER:
			return "Protegé a una persona durante la noche."
		PlayerState.Role.INQUISITOR:
			return "Investigá a una persona durante la noche."
		_:
			return "Esperando la voluntad de los dioses."

func _build_session(roster: Dictionary) -> MatchSession:
	if roster.size() < MatchSession.MIN_PLAYERS:
		return null
	var session := MatchSession.new()
	var peer_ids := roster.keys()
	peer_ids.sort()
	for raw_peer_id in peer_ids:
		var peer_id := int(raw_peer_id)
		var data: Dictionary = roster[raw_peer_id]
		if not session.add_player(peer_id, int(data.get("steam_id", 0)), str(data.get("display_name", ""))):
			return null
		var player := session.get_player(peer_id)
		player.seat_id = int(data.get("seat_id", -1))
	return session

func _dispatch_private_roles() -> void:
	for player in _session.players:
		if player.peer_id == multiplayer.get_unique_id():
			_receive_private_role(int(player.role))
		else:
			_receive_private_role.rpc_id(player.peer_id, int(player.role))

@rpc("authority", "call_remote", "reliable")
func _receive_private_role(role_value: int) -> void:
	if role_value <= PlayerState.Role.UNASSIGNED or role_value > PlayerState.Role.INQUISITOR:
		return
	local_role = role_value as PlayerState.Role
	private_role_received.emit(int(local_role))
