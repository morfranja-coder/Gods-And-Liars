class_name HostMigrationSnapshotRemapper
extends RefCounted

const OLD_HOST_PEER_ID := 1
const DISCONNECTED_HOST_PEER_ID := 2147483647

static func remap(
	snapshot: MatchSnapshot,
	old_to_new_peer_ids: Dictionary,
) -> MatchSnapshot:
	if snapshot == null or not snapshot.is_valid():
		return null
	var peer_map := old_to_new_peer_ids.duplicate()
	peer_map[OLD_HOST_PEER_ID] = DISCONNECTED_HOST_PEER_ID
	var data := snapshot.to_dictionary()
	data["players"] = _remap_players(snapshot.players, peer_map)
	data["role_acknowledged"] = _remap_dictionary(snapshot.role_acknowledged, peer_map, false)
	data["heretic_targets"] = _remap_dictionary(snapshot.heretic_targets, peer_map, true)
	data["healer_target_peer_id"] = _remap_target_reference(snapshot.healer_target_peer_id, peer_map)
	data["inquisitor_target_peer_id"] = _remap_target_reference(snapshot.inquisitor_target_peer_id, peer_map)
	data["votes"] = _remap_dictionary(snapshot.votes, peer_map, true)
	return MatchSnapshot.from_dictionary(data)

static func _remap_players(
	players: Array[Dictionary],
	peer_map: Dictionary,
) -> Array[Dictionary]:
	var remapped: Array[Dictionary] = []
	for source in players:
		var data := source.duplicate(true)
		var old_peer_id := int(source.get("peer_id", 0))
		data["peer_id"] = _remap_identity_reference(old_peer_id, peer_map)
		data["selected_target_peer_id"] = _remap_target_reference(
			int(source.get("selected_target_peer_id", 0)),
			peer_map,
		)
		data["vote_target_peer_id"] = _remap_target_reference(
			int(source.get("vote_target_peer_id", 0)),
			peer_map,
		)
		if old_peer_id == OLD_HOST_PEER_ID:
			data["alive"] = false
			data["selected_target_peer_id"] = 0
			data["vote_target_peer_id"] = 0
		remapped.append(data)
	return remapped

static func _remap_dictionary(
	source: Dictionary,
	peer_map: Dictionary,
	remap_values: bool,
) -> Dictionary:
	var result: Dictionary = {}
	for raw_key in source.keys():
		var old_key := int(raw_key)
		if old_key == OLD_HOST_PEER_ID:
			continue
		var new_key := _remap_identity_reference(old_key, peer_map)
		if new_key <= 0:
			continue
		var value = source[raw_key]
		if remap_values:
			var new_value := _remap_target_reference(int(value), peer_map)
			if new_value <= 0:
				continue
			result[new_key] = new_value
		else:
			result[new_key] = value
	return result

static func _remap_identity_reference(peer_id: int, peer_map: Dictionary) -> int:
	if peer_id <= 0:
		return 0
	return int(peer_map.get(peer_id, 0))

static func _remap_target_reference(peer_id: int, peer_map: Dictionary) -> int:
	if peer_id <= 0 or peer_id == OLD_HOST_PEER_ID:
		return 0
	return int(peer_map.get(peer_id, 0))
