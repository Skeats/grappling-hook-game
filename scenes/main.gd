extends Node3D

const PLAYER = preload("res://prefabs/player/player.tscn")

@onready var player_spawn: Marker3D = %PlayerSpawn

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Network.player_connected.connect(_on_player_connected)
	Network.player_disconnected.connect(_on_player_disconnected)

func spawn_player(player_id: int) -> void:
	var player := PLAYER.instantiate()
	player.name = "Player%s" % player_id
	player.add_to_group("Players")
	player.global_transform = player_spawn.global_transform
	get_tree().current_scene.add_child(player, true)

func remove_player(player_id: int) -> void:
	for player in get_tree().get_nodes_in_group("Players"):
		if player.name.to_int() == player_id:
			player.queue_free()

func _on_player_connected(id, player_info):
	if multiplayer.is_server() and not get_tree().current_scene.find_child("Player" + str(id)):
		spawn_player(id)

func _on_player_disconnected(id):
	if multiplayer.is_server():
		remove_player(id)
