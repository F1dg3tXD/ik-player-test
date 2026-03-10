extends Node

signal lobby_created(lobby_id)
signal lobby_joined(lobby_id)

var pending_lobby_name := "WEEP Lobby"

func _ready():
	SteamManager.connect("lobby_created", _on_lobby_created)
	SteamManager.connect("lobby_joined", _on_lobby_joined)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)

# ------------------------------------------------
# CREATE LOBBY
# ------------------------------------------------

func host_steam_lobby(max_players:int):
	SteamManager.create_lobby(Steam.LOBBY_TYPE_PUBLIC, max_players)

# ------------------------------------------------
# JOIN LOBBY
# ------------------------------------------------

func join_steam_lobby(lobby_id:int):
	SteamManager.join_lobby(lobby_id)

# ------------------------------------------------
# STEAM CALLBACKS
# ------------------------------------------------

func _on_lobby_created(result:int, lobby_id:int):
	if result != Steam.RESULT_OK:
		push_error("Failed to create lobby")
		return
	print("Steam lobby created")
	NetworkManager.start_steam_host()
	await get_tree().process_frame
	await get_tree().process_frame
	var spawn := get_tree().current_scene.get_node("spawnPoints")
	spawn.spawn_player(multiplayer.get_unique_id())
	Steam.setLobbyData(lobby_id,"game","WEEPGame")
	Steam.setLobbyData(lobby_id,"name",pending_lobby_name)
	emit_signal("lobby_created", lobby_id)
	_hide_menu()


func _on_lobby_joined(lobby_id:int, _p:int, _l:bool, _r:int):
	var host_id = Steam.getLobbyOwner(lobby_id)
	var my_id = Steam.getSteamID()
	print("My ID:",my_id)
	print("Host ID:",host_id)
	emit_signal("lobby_joined", lobby_id)
	if my_id != host_id:
		await get_tree().process_frame
		NetworkManager.start_steam_client(host_id)

# ------------------------------------------------
# NETWORK EVENTS
# ------------------------------------------------

func _on_peer_connected(id:int):
	print("Peer connected:",id)
	if multiplayer.is_server():
		var spawn := get_tree().current_scene.get_node("spawnPoints")
		spawn.spawn_player(id)


func _on_connected_to_server():
	print("Connected to host")

# ------------------------------------------------
# UI
# ------------------------------------------------

func _hide_menu():
	var scene = get_tree().current_scene
	if scene == null:
		return
	var menu = scene.get_node("Cameras/MenuCamera/Menu")
	if menu:
		menu.visible = false
