extends Node3D

signal crosshair_changed(crosshair)

const PLAYER = preload("res://prefabs/player/player.tscn")

const CROSSHAIRS = {
	"grapple_hook": preload("res://prefabs/ui/crosshair/grappling_hook/grapple_hook.tscn")
}

var crosshair: Control :
	set(value):
		crosshair = value
		crosshair_changed.emit(crosshair)

@onready var player_spawn: Marker3D = %PlayerSpawn
@onready var player_spawner: MultiplayerSpawner = %PlayerSpawner
@onready var player_hud: CanvasLayer = %PlayerHUD

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Network.player_connected.connect(_on_player_connected)
	Network.player_disconnected.connect(_on_player_disconnected)

	player_spawner.spawn_function = spawn_player

	change_crosshair("grapple_hook")

func change_crosshair(crosshair_name: String) -> void:
	if CROSSHAIRS.has(crosshair_name):
		if crosshair:
			crosshair.queue_free()
		crosshair = CROSSHAIRS[crosshair_name].instantiate()
		player_hud.add_child(crosshair)

func spawn_player(player_id: int) -> Node3D:
	var player := PLAYER.instantiate()
	player.name = "Player%s" % player_id
	player.add_to_group("Players")
	#player.global_transform = player_spawn.global_transform
	return player

func remove_player(player_id: int) -> void:
	for player in get_tree().get_nodes_in_group("Players"):
		if player.name.to_int() == player_id:
			player.queue_free()

func _on_player_connected(id: int, _player_info: Dictionary):
	if multiplayer.is_server() and not get_tree().current_scene.find_child("Player" + str(id)):
		player_spawner.spawn(id)

func _on_player_disconnected(id):
	if multiplayer.is_server():
		remove_player(id)
