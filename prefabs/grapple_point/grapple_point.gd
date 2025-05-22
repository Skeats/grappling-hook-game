@tool
class_name GrapplePoint
extends StaticBody3D

const GRAPPLE_MATERIAL = preload("res://prefabs/grapple_point/grapple_material.tres")

@export var shape: Shape3D = BoxShape3D.new() :
	set(value):
		shape = value
		change_shape()

var collider: CollisionShape3D
var mesh_instance: MeshInstance3D

func _ready() -> void:
	collider = CollisionShape3D.new()
	mesh_instance = MeshInstance3D.new()
	add_child(collider)
	add_child(mesh_instance)

	if Engine.is_editor_hint():
		collider.owner = get_tree().edited_scene_root
		mesh_instance.owner = get_tree().edited_scene_root

	set_collision_layer_value(2, true)
	change_shape()

func _exit_tree() -> void:
	for child in get_children():
		child.queue_free()

func change_shape() -> void:
	shape.changed.connect(update_appearance)
	update_appearance()

func update_appearance() -> void:
	if not shape or not collider: return

	collider.shape = shape
	print("Updating grapple point mesh")

	match shape.get_class():
		"BoxShape3D":
			mesh_instance.mesh = BoxMesh.new()
			mesh_instance.mesh.size = shape.size
		"SphereShape3D":
			mesh_instance.mesh = SphereMesh.new()
			mesh_instance.mesh.radius = shape.radius
			mesh_instance.mesh.height = shape.radius * 2

	mesh_instance.mesh.surface_set_material(0, GRAPPLE_MATERIAL)
