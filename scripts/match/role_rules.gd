class_name RoleRules
extends RefCounted

static func build_role_pool(player_count: int) -> Array[PlayerState.Role]:
	assert(player_count >= 4)
	var roles: Array[PlayerState.Role] = []
	var heretics := 1 if player_count <= 6 else 2
	for _i in range(heretics):
		roles.append(PlayerState.Role.HERETIC)
	roles.append(PlayerState.Role.HEALER)
	roles.append(PlayerState.Role.INQUISITOR)
	while roles.size() < player_count:
		roles.append(PlayerState.Role.FAITHFUL)
	return roles

static func assign_roles(players: Array[PlayerState], rng: RandomNumberGenerator) -> void:
	var roles := build_role_pool(players.size())
	for i in range(roles.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp := roles[i]
		roles[i] = roles[j]
		roles[j] = temp
	for i in players.size():
		players[i].role = roles[i]

static func winner(players: Array[PlayerState]) -> StringName:
	var alive_heretics := 0
	var alive_faithful_side := 0
	for player in players:
		if not player.alive:
			continue
		if player.role == PlayerState.Role.HERETIC:
			alive_heretics += 1
		else:
			alive_faithful_side += 1
	if alive_heretics == 0:
		return &"faithful"
	if alive_heretics >= alive_faithful_side:
		return &"heretics"
	return &""
