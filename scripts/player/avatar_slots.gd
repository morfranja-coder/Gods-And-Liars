class_name AvatarSlots
extends Node3D

@export var body_scene: PackedScene
@export var tunic_scene: PackedScene
@export var mask_scene: PackedScene

@onready var body_root: Node3D = $Body
@onready var tunic_root: Node3D = $Tunic
@onready var mask_root: Node3D = $Mask

func _ready() -> void:
	_refresh_all()

func set_body(scene: PackedScene) -> void:
	body_scene = scene
	_replace_child(body_root, body_scene)

func set_tunic(scene: PackedScene) -> void:
	tunic_scene = scene
	_replace_child(tunic_root, tunic_scene)

func set_mask(scene: PackedScene) -> void:
	mask_scene = scene
	_replace_child(mask_root, mask_scene)

func _refresh_all() -> void:
	_refresh_slot(body_root, body_scene)
	_refresh_slot(tunic_root, tunic_scene)
	_refresh_slot(mask_root, mask_scene)

func _refresh_slot(root: Node3D, scene: PackedScene) -> void:
	if scene == null:
		return
	_replace_child(root, scene)

func _replace_child(root: Node3D, scene: PackedScene) -> void:
	for child in root.get_children():
		child.queue_free()
	if scene == null:
		return
	var instance := scene.instantiate()
	root.add_child(instance)
