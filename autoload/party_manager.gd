extends Node

signal party_changed
signal party_error(message: String)

var state := PartyState.new()

func _ready() -> void:
	Steamworks.steam_ready.connect(_reset_from_local_identity)
	Steamworks.steam_unavailable.connect(_on_steam_unavailable)
	if Steamworks.initialized:
		_reset_from_local_identity()

func reset_to_solo() -> void:
	if not Steamworks.initialized or Steamworks.steam_id <= 0:
		state = PartyState.new()
		party_changed.emit()
		return
	state.reset_to_solo(Steamworks.steam_id, Steamworks.persona_name)
	party_changed.emit()

func apply_snapshot(party_id: int, leader_steam_id: int, members: Dictionary) -> bool:
	var next_state := PartyState.new()
	if not next_state.set_snapshot(party_id, leader_steam_id, members):
		party_error.emit("Party snapshot inválido.")
		return false
	if Steamworks.initialized and not next_state.members.has(Steamworks.steam_id):
		party_error.emit("El Party snapshot no contiene al jugador local.")
		return false
	state = next_state
	party_changed.emit()
	return true

func size() -> int:
	return state.size()

func slots_available() -> int:
	return state.slots_available()

func is_local_leader() -> bool:
	return Steamworks.initialized and state.is_leader(Steamworks.steam_id)

func can_queue() -> bool:
	return state.can_queue() and is_local_leader()

func member_ids() -> Array[int]:
	return state.member_ids()

func _reset_from_local_identity() -> void:
	reset_to_solo()

func _on_steam_unavailable(_reason: String) -> void:
	state = PartyState.new()
	party_changed.emit()
