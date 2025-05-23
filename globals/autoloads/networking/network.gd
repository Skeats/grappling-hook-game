extends Node

# These signals can be connected to by a UI lobby scene or the game scene.
signal network_type_changed(network_type)
signal player_connected(peer_id, player_info)
signal player_disconnected(peer_id)
signal server_disconnected
signal connection_fail
signal player_ready
signal server_started
signal lobbies_fetched(lobbies)

enum MultiplayerNetworkType { DISABLED, ENET, STEAM }

const ROOM_SIZE = 4

var active_network_type : MultiplayerNetworkType = MultiplayerNetworkType.DISABLED :
	set(value):
		active_network_type = value
		network_type_changed.emit(active_network_type)
var active_network : Node

# General Variables
var is_host : bool
var connected_players = {}
var player_info = {
	"name": "Name"
}
var players_ready : Array[int]

var ip_address : String = "127.0.0.1" # IPv4 localhost

# Steam Variables
var steam_lobby_data = {
	"name": "MOVEMENTSHOOTER_TEST_LOBBY",
	"game": "DEFAULTSCENE"
}
var steam_lobby_id: int = 0

var dev_tools: Node = null

func _ready():
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connected_fail)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	# Sets the default username to the steam name, or if that doesnt exist, the OS name
	if Global.steam_username:
		Network.player_info["name"] = Global.steam_username
	elif OS.has_environment("USERNAME"):
		Network.player_info["name"] = OS.get_environment("USERNAME")
	else:
		var desktop_path := OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP).replace("\\", "/").split("/")
		Network.player_info["name"] = desktop_path[desktop_path.size() - 2]

	if is_inside_tree() and get_tree().root.has_node("DevTools"):
		dev_tools = get_tree().root.find_child("DevTools")
		dev_tools.create_command("set_network", dev_set_network, "Sets the network type. Call without arguments to list available networks")
		dev_tools.create_command("host_lobby", dev_host_lobby, "Hosts a lobby using the current adtive network")
		dev_tools.create_command("connect", dev_join_lobby, "Connects to the given lobby")
		dev_tools.create_command("disconnect", dev_disconnect, "Disconnnects from the current lobby")

#region Dev Commands
func dev_set_network(args: Array[String]):
	if args:
		match args[0]:
			"Steam":
				active_network_type = MultiplayerNetworkType.STEAM
			"Enet":
				active_network_type = MultiplayerNetworkType.ENET
			"None":
				active_network_type = MultiplayerNetworkType.DISABLED
			_:
				return "[color=red]ERROR: No network type named " + args[0] + "[/color]"

		_build_multiplayer_network(true)
		return "Network type changed to " + args[0]
	else:
		return "Available Arguments: [color=green]\nSteam\nEnet\nNone[/color]"

func dev_host_lobby():
	become_host()

func dev_join_lobby(args: Array[String]):
	if active_network_type == MultiplayerNetworkType.STEAM:
		steam_lobby_id = args[0].to_int()
	else:
		if args:
			ip_address = args[0]

	join_as_client()


func dev_disconnect():
	disconnect_from_server()
#endregion

#region Network Setup

## Sets the active network to the active network type
func _build_multiplayer_network(destroy_previous_network : bool = false):
	if not active_network or destroy_previous_network:
		match active_network_type:
			MultiplayerNetworkType.ENET:
				if dev_tools:
					dev_tools.printy("Setting network type to ENet", [dev_tools.Tags.NETWORK])
				_set_active_network(NetworkEnet)
			MultiplayerNetworkType.STEAM:
				if dev_tools:
					dev_tools.printy("Setting network type to Steam", [dev_tools.Tags.NETWORK])
				_set_active_network(NetworkSteam)
			MultiplayerNetworkType.DISABLED:
				if dev_tools:
					dev_tools.printy("Disabled networking", [dev_tools.Tags.NETWORK])
				_remove_active_network()
			_:
				if dev_tools:
					dev_tools.printy("No match for network type", [dev_tools.Tags.NETWORK, dev_tools.Tags.WARN])

## Builds a network scene based on the passed parameters
func _set_active_network(new_network_type : Object):
	_remove_active_network()
	active_network = new_network_type.new()
	add_child(active_network, true)

## Removes the current active network, if one exists
func _remove_active_network():
	if is_instance_valid(active_network):
		active_network.queue_free()
#endregion

#region Network-Specific Functions

func become_host(lobby_type : Steam.LobbyType = Steam.LobbyType.LOBBY_TYPE_PUBLIC):
	_build_multiplayer_network()
	active_network.become_host(lobby_type)

func join_as_client(): # server_connector should be either an IP or a Steam lobby id
	_build_multiplayer_network()
	active_network.join_as_client()

## Disconnects the current peer from any connected servers
## @param network_type - The network type to use after disconnecting from the server, this is useful
## for instances such as Steam, where you may want to continue looking for lobbies even after
## disconnecting from a server
func disconnect_from_server(network_type : MultiplayerNetworkType = MultiplayerNetworkType.DISABLED):
	# This expression may not be necessary
	if Network.steam_lobby_id != 0:
		Steam.leaveLobby(Network.steam_lobby_id)

	active_network_type = network_type
	multiplayer.multiplayer_peer = null
	connected_players.clear()
	steam_lobby_id = 0
	_build_multiplayer_network(true)

func list_lobbies():
	_build_multiplayer_network()
	active_network.list_lobbies()
#endregion

#region MultiplayerAPI Signals

# When a peer connects, send them my player info.
# This allows transfer of all desired data for each player, not only the unique ID.
func _on_player_connected(id : int):
	_register_player.rpc_id(id, player_info)

# Runs whenever on all peers when a peer is disconnected
func _on_player_disconnected(id : int):
	connected_players.erase(id)
	players_ready.erase(id)
	player_disconnected.emit(id)

# Runs on the local peer when it connects to a server
func _on_connected_ok():
	var peer_id = multiplayer.get_unique_id()
	connected_players[peer_id] = player_info
	if dev_tools:
		dev_tools.printy("[" + str(multiplayer.get_unique_id()) + "]: Joined server", [dev_tools.Tags.NETWORK])
	player_connected.emit(peer_id, player_info)

# Runs on the local peer when it fails to connect to the server
func _on_connected_fail():
	disconnect_from_server()
	connection_fail.emit

# Runs on the local peer when the server is disconnected
func _on_server_disconnected():
	disconnect_from_server()
	server_disconnected.emit()
	if dev_tools:
		dev_tools.printy("Disconnected from server", [dev_tools.Tags.NETWORK])
#endregion

#region Ready RPCs
@rpc("any_peer", "call_local", "reliable")
func ready_state(toggled_on : bool):
	if multiplayer.is_server():
		var sender_id = multiplayer.get_remote_sender_id()

		if toggled_on and !players_ready.has(sender_id):
			players_ready.append(sender_id)
		elif !toggled_on:
			players_ready.erase(sender_id)

		propagate_ready_states.rpc(players_ready)

@rpc("authority", "call_local", "reliable")
func propagate_ready_states(server_ready_states : Array[int]):
	players_ready = server_ready_states
	player_ready.emit()
#endregion

# Called during peer_connected on all peers
@rpc("any_peer", "reliable")
func _register_player(new_player_info : Dictionary):
	var new_player_id = multiplayer.get_remote_sender_id()
	connected_players[new_player_id] = new_player_info
	propagate_ready_states.rpc_id(new_player_id, players_ready)
	player_connected.emit(new_player_id, new_player_info)
