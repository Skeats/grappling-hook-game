class_name NetworkEnet
extends Node

const PORT = 7000
const MAX_CONNECTIONS = 4

# We can define this on initialization because this script should only run if we are going to be
# networking using ENet
var peer : ENetMultiplayerPeer = ENetMultiplayerPeer.new()

#region Network-Specific Functions

# Creates a game server as the host
func become_host(_lobby_type):
	var error = peer.create_server(PORT, Network.ROOM_SIZE)
	if error:
		return error
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)

	multiplayer.multiplayer_peer = peer

	Network.connected_players[1] = Network.player_info
	Network.server_started.emit()
	Network.player_connected.emit(1, Network.player_info)
	if Network.dev_tools:
		Network.dev_tools.printy("ENet Server hosted on port " + str(PORT), [Network.dev_tools.Tags.NETWORK])

# Joins a game server using the provided address
func join_as_client():
	var error = peer.create_client(Network.ip_address, PORT)
	if error:
		return error
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)

	multiplayer.multiplayer_peer = peer

# Does nothing as the ENet networking has no lobby implementation, but it's here
# simply to prevent any errors
func list_lobbies():
	pass
#endregion
