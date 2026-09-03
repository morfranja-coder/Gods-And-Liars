class_name AvatarSlots
extends Node3D

const MASK_MATERIAL_NAME := "M_Mask"
const IDLE_ANIMATION := &"Idle"
const DEATH_ANIMATION := &"NlaTrack.013"
const DEATH_FALLBACK_SECONDS := 2.4
const MOVEMENT_ANIMATIONS := [
	&"NlaTrack",
	&"NlaTrack.001",
	&"NlaTrack.002",
	&"NlaTrack.003",
	&"NlaTrack.004",
	&"NlaTrack.005",
	&"NlaTrack.006",
	&"NlaTrack.007",
]

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
	_play_idle()

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
	_apply_name_color()

func get_player_color() -> Color:
	return _player_color

func set_local_perspective(enabled: bool) -> void:
	body_root.visible = not enabled
	tunic_root.visible = not enabled
	mask_root.visible = not enabled
	var label := get_node_or_null("NameLabel") as Label3D
	if label != null:
		label.visible = not enabled

func play_movement(index: int) -> bool:
	if index < 0 or index >= MOVEMENT_ANIMATIONS.size():
		return false
	var animation_player := _find_animation_player(self)
	var animation_name: StringName = MOVEMENT_ANIMATIONS[index]
	if animation_player == null or not animation_player.has_animation(animation_name):
		return false
	animation_player.play(animation_name, 0.15)
	return true

func _play_idle() -> bool:
	var animation_player := _find_animation_player(self)
	if animation_player == null or not animation_player.has_animation(IDLE_ANIMATION):
		return false
	var idle_animation := animation_player.get_animation(IDLE_ANIMATION)
	if idle_animation != null:
		idle_animation.loop_mode = Animation.LOOP_LINEAR
	animation_player.play(IDLE_ANIMATION)
	return true

func play_death_and_hide() -> void:
	var animation_player := _find_animation_player(self)
	if animation_player != null and animation_player.has_animation(DEATH_ANIMATION):
		animation_player.play(DEATH_ANIMATION)
		await animation_player.animation_finished
	else:
		await get_tree().create_timer(DEATH_FALLBACK_SECONDS).timeout
	visible = false

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null

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

func _apply_name_color() -> void:
	if not _has_player_color:
		return
	var label := get_node_or_null("NameLabel") as Label3D
	if label == null:
		return
	label.modulate = _player_color
	label.outline_modulate = Color(0.03, 0.03, 0.03, 1.0)
	label.outline_size = 10

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
