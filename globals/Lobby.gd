# Lobby.gd (Autoload)
extends Node

signal player_connected(peer_id, info)
signal player_disconnected(peer_id)
signal lobby_joined(lobby_id)
signal lobby_created(lobby_id)

var _last_seed : int = 0

# A small player struct
var players : Dictionary = {}
var players_ready : Dictionary = {}
var local_player_info : Dictionary = {
	"name": Steam.getPersonaName(),
	"color": Color.WHITE,
	"avatar": null
}

# Steam lobby state
var is_friends_only : bool = false
var has_password : bool = false
var lobby_password : String = ""
var pending_lobby_name : String = "WEEP Lobby"

# callbacks from SteamManager
func _ready() -> void:
	SteamManager.connect("lobby_created", Callable(self, "_on_steam_lobby_created"))
	SteamManager.connect("lobby_joined", Callable(self, "_on_steam_lobby_joined"))
	SteamManager.connect("join_requested", Callable(self, "_on_steam_join_requested"))

	# Hook engine multiplayer signals
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
func _get_menu():
	return get_tree().current_scene.get_node("Cameras/MenuCamera/Menu")

# ---------- Public API used by UI ----------
func host_local_game(port: int = 7000, max_clients: int = 8) -> void:
	NetworkManager.start_local_server(port, max_clients)

func join_local_game(addr: String, port: int = 7000) -> void:
	NetworkManager.start_local_client(addr, port)
	# after connected, connected_to_server will trigger

func host_steam_lobby(max_players: int = 8, 
	friends_only_flag: bool = false, 
	password_enabled: bool = false, 
	password_text: String = ""
) -> void:
	
	is_friends_only = friends_only_flag
	has_password = password_enabled
	lobby_password = password_text
	
	var lobby_type = Steam.LOBBY_TYPE_PUBLIC
	
	if is_friends_only:
		lobby_type = Steam.LOBBY_TYPE_FRIENDS_ONLY
		
	SteamManager.create_lobby(lobby_type, max_players)

func join_steam_lobby(lobby_id: int) -> void:
	SteamManager.join_lobby(lobby_id)
	
func _hide_menu_if_player_exists():
	var scene = get_tree().current_scene
	if scene == null:
		return
	var players_node = scene.get_node("Players")
	var my_id = multiplayer.get_unique_id()
	if players_node.has_node(str(my_id)):
		_get_menu().hide()

# Called when Steam returns that lobby was created (host side)
func _on_steam_lobby_created(result: int, lobby_id: int) -> void:
	if multiplayer.multiplayer_peer != null:
		return
	if result != Steam.Result.RESULT_OK:
		push_error("Failed to create steam lobby: %s" % result)
		return
	print("Steam Host Started")
	NetworkManager.set_peer_mode(NetworkManager.PeerMode.STEAM)
	NetworkManager.start_steam_host()
	await get_tree().process_frame
	var spawn = get_tree().current_scene.get_node("spawnPoints")
	spawn.spawn_player(multiplayer.get_unique_id())
	emit_signal("lobby_created", lobby_id)
	Steam.setLobbyData(lobby_id, "name", pending_lobby_name)
	Steam.setLobbyData(lobby_id, "game", "WEEPGame")
	Steam.setLobbyData(lobby_id, "friends_only", "1" if is_friends_only else "0")
	Steam.setLobbyData(lobby_id, "has_password", "1" if has_password else "0")
	# Spawn host player
	
	# Hide menu
	var menu_camera = get_tree().current_scene.get_node("Cameras/MenuCamera")
	menu_camera.enabled = false

# Called when Steam indicates we joined/entered a lobby
func _on_steam_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, _response: int) -> void:
	var host_id = Steam.getLobbyOwner(lobby_id)
	var my_id = Steam.getSteamID()
	print("My ID:", my_id)
	print("Host ID:", host_id)
	emit_signal("lobby_joined", lobby_id)
	if my_id != host_id:
		await get_tree().process_frame
		await get_tree().process_frame
		print("Connecting to Steam host:", host_id)
		NetworkManager.start_steam_client(host_id)

# Friend invite handling: Steam overlay friend invite acceptance
func _on_steam_join_requested(lobby_id: int) -> void:
	# auto-join the lobby invited to
	join_steam_lobby(lobby_id)

# ---------- multiplayer callbacks ----------
func _on_peer_connected(id: int) -> void:
	print("Peer connected:", id)
	if multiplayer.is_server():
		var spawn = get_tree().current_scene.get_node("spawnPoints")
		spawn.spawn_player(id)

func _on_peer_disconnected(id: int) -> void:
	players.erase(id)
	emit_signal("player_disconnected", id)

func _on_connected_to_server() -> void:
	if multiplayer.is_server():
		var spawn = get_tree().current_scene.get_node("spawnPoints")
		spawn.spawn_player(multiplayer.get_unique_id())
	# local client: send our info immediately to server
	rpc_id(1, "_send_local_player_info")
	rpc_id(1, "client_scene_ready")

func _on_connection_failed() -> void:
	print("Steam connection failed.")
	print("Peers:", multiplayer.get_peers())
	push_error("Connection failed — cleanup if needed.")

func _on_server_disconnected() -> void:
	push_error("Server disconnected — handle return to menu")
	
# ---------- Scene: default loader ----------
func start_simple_scene(map_scene_path: String) -> void:
	# Only server should invoke this shortcut.
	if not multiplayer.is_server():
		return
	_last_seed = 0
	# Host loads the simple scene for themselves and tells clients to load it
	_rpc_load_simple_scene(map_scene_path)
	rpc("_rpc_load_simple_scene", map_scene_path)

# ---------- RPCs: info transfer ----------
@rpc("any_peer", "reliable")
func _send_local_player_info() -> void:
	# Called on server by client (rpc_id from client) or called on clients by server
	var from = multiplayer.get_remote_sender_id()
	players[from] = local_player_info.duplicate(true)
	emit_signal("player_connected", from, players[from])
	# Server should then broadcast roster to everyone if desired:
	if multiplayer.is_server():
		rpc("_sync_full_roster", players)

@rpc("any_peer", "reliable")
func _sync_full_roster(roster: Dictionary) -> void:
	players = roster.duplicate(true)

@rpc("any_peer","reliable")
func client_scene_ready():
	if not multiplayer.is_server():
		return
	var peer_id = multiplayer.get_remote_sender_id()
	print("Client scene ready:", peer_id)
	var spawn = get_tree().current_scene.get_node("spawnPoints")
	await spawn.spawn_points_ready
	spawn.spawn_player(peer_id)
	_hide_menu_if_player_exists()

# ---------- Host starts the real game ----------
# Called when host wants to start whole game with generated map (seeded)
func start_game_on_host(map_scene_path: String) -> void:
	if not multiplayer.is_server():
		return
	# If host wants to ensure at least one client is connected, wait:
	if multiplayer.get_peers().is_empty():
		print("[Lobby] Waiting for at least one peer to be connected before starting...")
		await multiplayer.peer_connected
	var dungeon_seed = randi()
	# Then tell clients to load
	rpc("_rpc_load_game_scene", dungeon_seed, map_scene_path)

@rpc("any_peer", "reliable")
func _rpc_load_simple_scene(map_scene_path: String) -> void:
	print("[Lobby] _rpc_load_simple_scene -> loading:", map_scene_path)
	get_tree().change_scene_to_file(map_scene_path)
	
