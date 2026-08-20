class_name PlayerState
extends RefCounted

enum Role {
	UNASSIGNED,
	FAITHFUL,
	HERETIC,
	HEALER,
	INQUISITOR,
}

var peer_id: int = 0
var steam_id: int = 0
var display_name: String = ""
var seat_id: int = -1
var role: Role = Role.UNASSIGNED
var alive: bool = true
var ready: bool = false
var selected_target_peer_id: int = 0
var vote_target_peer_id: int = 0

func _init(p_peer_id: int = 0, p_steam_id: int = 0, p_display_name: String = "") -> void:
	peer_id = p_peer_id
	steam_id = p_steam_id
	display_name = p_display_name

func reset_for_match() -> void:
	role = Role.UNASSIGNED
	alive = true
	selected_target_peer_id = 0
	vote_target_peer_id = 0

func is_heretic() -> bool:
	return role == Role.HERETIC
