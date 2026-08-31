class_name AvatarSlots
extends Node3D

const MASK_MATERIAL_NAME := "M_Mask"

@export var body_scene: PackedScene
@export var tunic_scene: PackedScene
@export var mask_scene: PackedScene

var _player_color: Color = Color.WHITE
var _has_player_color: bool = false

@onready var body_root: Node3D = $Body
@onready var tunic_root: Node3D = $Tunic
@onready var mask_root: Node3D = $Mask

func _ready() -> void:
	_refresh_all()
	_apply_mask_color()

func set_body(scene: PackedScene) -> void:
	body_scene = scene
	_replace_child(body_root, body_scene)

func set_tunic(scene: PackedScene) -> void:
	tunic_scene = scene
	_replace_child(tunic_root, tunic_scene)

func set_mask(scene: PackedScene) -> void:
	mask_scene = scene
	_replace_child(mask_root, mask_scene)

func set_player_color(color: Color) -> void:
	_player_color = color
	_has_player_color = true
	_apply_mask_color()

func get_player_color() -> Color:
	return _player_color

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
	_apply_mask_color()

func _apply_mask_color() -> void:
	if not _has_player_color:
		return
	_tint_mask_materials(self)

func _tint_mask_materials(node: Node) -> void:
	if node is MeshInstance3D:
		_tint_mesh_instance(node as MeshInstance3D)
	for child in node.get_children():
		_tint_mask_materials(child)

func _tint_mesh_instance(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance.mesh == null:
		return
	for surface_index in range(mesh_instance.mesh.get_surface_count()):
		var material := mesh_instance.mesh.surface_get_material(surface_index)
		if material == null or material.resource_name != MASK_MATERIAL_NAME:
			continue
		if material is not BaseMaterial3D:
			continue
		var tinted_material := material.duplicate() as BaseMaterial3D
		tinted_material.resource_name = "%s_Instance" % MASK_MATERIAL_NAME
		tinted_material.albedo_color = _player_color
		mesh_instance.set_surface_override_material(surface_index, tinted_material)
