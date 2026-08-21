class_name PartyState
extends RefCounted

var party_id: int = 0
var leader_steam_id: int = 0
var members: Dictionary = {}

func reset_to_solo(steam_id: int, display_name: String) -> void:
	party_id = steam_id
	leader_steam_id = steam_id
	members.clear()
	if steam_id > 0:
		members[steam_id] = display_name

func set_snapshot(new_party_id: int, new_leader_steam_id: int, new_members: Dictionary) -> bool:
	if new_party_id <= 0 or new_leader_steam_id <= 0:
		return false
	if new_members.is_empty() or new_members.size() > QuickMatchRules.MAX_PARTY_SIZE:
		return false
	if not new_members.has(new_leader_steam_id):
		return false
	party_id = new_party_id
	leader_steam_id = new_leader_steam_id
	members = new_members.duplicate(true)
	return true

func add_member(steam_id: int, display_name: String) -> bool:
	if steam_id <= 0 or members.has(steam_id) or members.size() >= QuickMatchRules.MAX_PARTY_SIZE:
		return false
	members[steam_id] = display_name
	return true

func remove_member(steam_id: int) -> bool:
	if not members.has(steam_id):
		return false
	members.erase(steam_id)
	if steam_id == leader_steam_id:
		leader_steam_id = _first_member_id()
	return true

func size() -> int:
	return members.size()

func slots_available() -> int:
	return QuickMatchRules.TARGET_PLAYERS - size()

func can_queue() -> bool:
	return QuickMatchRules.valid_party_size(size()) and leader_steam_id > 0

func is_leader(steam_id: int) -> bool:
	return steam_id > 0 and steam_id == leader_steam_id

func member_ids() -> Array[int]:
	var result: Array[int] = []
	for raw_id in members.keys():
		result.append(int(raw_id))
	result.sort()
	return result

func _first_member_id() -> int:
	var ids := member_ids()
	return 0 if ids.is_empty() else ids[0]
