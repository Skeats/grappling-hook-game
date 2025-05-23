class_name NetworkSteam
extends Node

const PACKET_READ_LIMIT: int = 32

var peer : SteamMultiplayerPeer = SteamMultiplayerPeer.new()

func _ready() -> void:
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)
	#Steam.join_requested.connect(_on_lobby_join_requested)
	Steam.lobby_match_list.connect(_on_lobby_match_list)

#region Main Network Function

# Creates a game server as the host
func become_host(lobby_type : Steam.LobbyType = Steam.LobbyType.LOBBY_TYPE_PUBLIC):
	if Network.steam_lobby_id == 0:
		Steam.createLobby(lobby_type, Network.ROOM_SIZE)

# Joins a game server using the provided address
func join_as_client():
	Steam.joinLobby(Network.steam_lobby_id)

func list_lobbies():
	Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)

	if Global.steam_app_id == 480:
		Steam.addRequestLobbyListStringFilter("name", Network.steam_lobby_data["name"], Steam.LOBBY_COMPARISON_EQUAL)
	Steam.requestLobbyList()
#endregion

#region Steam Functions

## Checks for command line args that would tell the game to connect to a specific server on startup
func check_command_line() -> void:
	var command_args: Array = OS.get_cmdline_args()

	# There are arguments to process
	if command_args.size() > 0:

		# A Steam connection argument exists
		if command_args[0] == "+connect_lobby":

			# Lobby invite exists so try to connect to it
			if int(command_args[1]) > 0:

				# At this point, you'll probably want to change scenes
				# Something like a loading into lobby screen
				if Network.dev_tools:
					Network.dev_tools.printy("Command line lobby ID: %s" % command_args[1], [Network.dev_tools.Tags.NETWORK])
				Network.steam_lobby_id = int(command_args[1])
				Network.is_host = false
				#get_tree().change_scene_to_packed(Global.scenes.MAIN)

#region Lobby/Host Startup

func _on_lobby_created(response : int, lobby_id : int):
	if response == 1:
		Network.steam_lobby_id = lobby_id
		if Network.dev_tools:
			Network.dev_tools.printy("Created lobby: %s" % lobby_id, [Network.dev_tools.Tags.NETWORK])

		Steam.setLobbyJoinable(Network.steam_lobby_id, true)

		for entry in Network.steam_lobby_data:
			Steam.setLobbyData(Network.steam_lobby_id, entry, Network.steam_lobby_data[entry])

		_create_host()

func _create_host():
	var error = peer.create_host(0)
	if error != OK:
		if Network.dev_tools:
			Network.dev_tools.printy("Error creating host: " + error_string(error), [Network.dev_tools.Tags.ERROR, Network.dev_tools.Tags.NETWORK])
		return error

	multiplayer.multiplayer_peer = peer
	Network.connected_players[1] = Network.player_info
	Network.server_started.emit()
	Network.player_connected.emit(1, Network.player_info)
	if Network.dev_tools:
		Network.dev_tools.printy("Steam Server hosted", [Network.dev_tools.Tags.NETWORK])

func _on_lobby_match_list(lobbies: Array) -> void:
	Network.lobbies_fetched.emit(lobbies)
#endregion

#region Lobby Joining

## I am not entirely clear on what this does, something to do with friend invites
# COME BACK TO THIS
#func _on_lobby_join_requested(this_lobby_id: int, friend_id: int) -> void:
	## Get the lobby owner's name
	#var owner_name: String = Steam.getFriendPersonaName(friend_id)
#
	#print("Joining %s's lobby..." % owner_name)
#
	## Attempt to join the lobby
	#join_as_client(this_lobby_id)

## Callback function once Steam tells the client that it has either connected or failed to connect
## to the lobby
func _on_lobby_joined(lobby_id : int, _permissions : int, _locked : bool, response : int):
	if response == Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		var id = Steam.getLobbyOwner(lobby_id)

		if id != Steam.getSteamID():
			connect_socket(id)
			if Network.dev_tools:
				Network.dev_tools.printy("Connecting client to socket...", [Network.dev_tools.Tags.NETWORK])
	else:
		# Get the failure reason
		var FAIL_REASON : String
		match response:
			2:  FAIL_REASON = "This lobby no longer exists."
			3:  FAIL_REASON = "You don't have permission to join this lobby."
			4:  FAIL_REASON = "The lobby is now full."
			5:  FAIL_REASON = "Uh... something unexpected happened!"
			6:  FAIL_REASON = "You are banned from this lobby."
			7:  FAIL_REASON = "You cannot join due to having a limited account."
			8:  FAIL_REASON = "This lobby is locked or disabled."
			9:  FAIL_REASON = "This lobby is community locked."
			10: FAIL_REASON = "A user in the lobby has blocked you from joining."
			11: FAIL_REASON = "A user you have blocked is in the lobby."
		if FAIL_REASON:
			if Network.dev_tools:
				Network.dev_tools.printy(FAIL_REASON, [Network.dev_tools.Tags.ERROR, Network.dev_tools.Tags.NETWORK])

## Creates a SteamMultiplayerPeer client
func connect_socket(steam_id : int):
	var error = peer.create_client(steam_id, 0)
	if error:
		if Network.dev_tools:
			Network.dev_tools.printy("Error creating client: " + str(error), [Network.dev_tools.Tags.ERROR, Network.dev_tools.Tags.NETWORK])
		return error

	if Network.dev_tools:
		Network.dev_tools.printy("Connecting peer to host...", [Network.dev_tools.Tags.NETWORK])
	multiplayer.multiplayer_peer = peer
#endregion
#endregion
