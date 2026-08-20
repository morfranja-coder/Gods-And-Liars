extends Node

signal steam_ready
signal steam_unavailable(reason: String)

var initialized: bool = false
var steam_id: int = 0
var persona_name: String = ""

func _ready() -> void:
	# Phase 0: keep Steam behind an adapter so the project can boot before
	# GodotSteam is installed. Real Steam initialization lands in Phase 1.
	initialized = false

func mark_ready(id: int, name: String) -> void:
	steam_id = id
	persona_name = name
	initialized = true
	steam_ready.emit()

func mark_unavailable(reason: String) -> void:
	initialized = false
	steam_unavailable.emit(reason)
