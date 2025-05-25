@tool
class_name GrapplePoint
extends StaticBody3D

const GRAPPLE_MATERIAL = preload("res://prefabs/grapple_point/grapple_material.tres")

@export var shape: Shape3D = BoxShape3D.new() :
	set(value):
		shape = value.duplicate()
		shape.resource_local_to_scene = true
		change_shape()

var collider: CollisionShape3D
var mesh_instance: MeshInstance3D

func _ready() -> void:
	for child in get_children():
		match child.get_class():
			"CollisionShape3D":
				collider = child
			"MeshInstance3D":
				mesh_instance = child

	if not collider:
		collider = CollisionShape3D.new()
		add_child(collider)

	if not mesh_instance:
		mesh_instance = MeshInstance3D.new()
		add_child(mesh_instance)

	if Engine.is_editor_hint():
		collider.owner = get_tree().edited_scene_root
		mesh_instance.owner = get_tree().edited_scene_root

	set_meta("_edit_group_", true)
	set_collision_layer_value(2, true)
	change_shape()

func _exit_tree() -> void:
	for child in get_children():
		child.queue_free()

func change_shape() -> void:
	if not shape.changed.has_connections():
		shape.changed.connect(update_appearance)
	update_appearance()

func update_appearance() -> void:
	if not shape or not collider: return

	collider.shape = shape
	print("Updating grapple point mesh")

	match shape.get_class():
		"BoxShape3D":
			mesh_instance.mesh = BoxMesh.new()
			mesh_instance.mesh.size = collider.shape.size
		"SphereShape3D":
			mesh_instance.mesh = SphereMesh.new()
			mesh_instance.mesh.radius = collider.shape.radius
			mesh_instance.mesh.height = collider.shape.radius * 2

	mesh_instance.mesh.surface_set_material(0, GRAPPLE_MATERIAL)
	mesh_instance.mesh.resource_local_to_scene = true
