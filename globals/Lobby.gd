# Lobby.gd (Autoload)
extends Node

signal player_connected(peer_id, info)
signal player_disconnected(peer_id)
signal lobby_joined(lobby_id)
signal lobby_created(lobby_id)


# A small player struct
var players : Dictionary = {}
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

# Called when Steam returns that lobby was created (host side)
func _on_steam_lobby_created(result: int, lobby_id: int) -> void:
	if result != Steam.Result.RESULT_OK:
		push_error("Failed to create steam lobby: %s" % result)
		return
	# mark lobby; create SteamMultiplayerPeer host
	NetworkManager.set_peer_mode(NetworkManager.PeerMode.STEAM)
	NetworkManager.start_steam_host()
	emit_signal("lobby_created", lobby_id)
	# Filter lobbies
	Steam.setLobbyData(lobby_id, "name", pending_lobby_name)
	Steam.setLobbyData(lobby_id, "game", "WEEPGame")
	# Friends only flag
	Steam.setLobbyData(lobby_id, "friends_only", "1" if is_friends_only else "0")
	# Password flag
	Steam.setLobbyData(lobby_id, "has_password", "1" if has_password else "0")
	# Let UI show lobby
	get_tree().change_scene_to_file("res://maps/Lobby.tscn")

# Called when Steam indicates we joined/entered a lobby
func _on_steam_lobby_joined(lobby_id: int, permissions: int, locked: bool, response: int) -> void:
	# The Steam extension uses response codes — check for success constant
	if response == Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		NetworkManager.set_peer_mode(NetworkManager.PeerMode.STEAM)
		# If we are not host, create client peer to owner
		var owner = Steam.getLobbyOwner(lobby_id)
		NetworkManager.start_steam_client(owner)
		emit_signal("lobby_joined", lobby_id)
	else:
		push_warning("Failed to join steam lobby: %s" % response)

# Friend invite handling: Steam overlay friend invite acceptance
func _on_steam_join_requested(lobby_id: int) -> void:
	# auto-join the lobby invited to
	join_steam_lobby(lobby_id)

# ---------- multiplayer callbacks ----------
func _on_peer_connected(id: int) -> void:
	# Host should register the joining player's info
	if multiplayer.is_server():
		# request the player's info; call an RPC that asks the new peer to send its player info
		rpc_id(id, "_send_local_player_info")

func _on_peer_disconnected(id: int) -> void:
	players.erase(id)
	emit_signal("player_disconnected", id)

func _on_connected_to_server() -> void:
	# local client: send our info immediately to server
	rpc_id(1, "_send_local_player_info") # assuming server is 1 on high level API

func _on_connection_failed() -> void:
	push_error("Connection failed — cleanup if needed.")

func _on_server_disconnected() -> void:
	push_error("Server disconnected — handle return to menu")

# ---------- RPCs: info transfer ----------
@rpc("any_peer", "reliable")
func _send_local_player_info() -> void:
	# Called on server by client (rpc_id from client) or called on clients by server
	var from = multiplayer.get_rpc_sender_id()
	players[from] = local_player_info.duplicate(true)
	emit_signal("player_connected", from, players[from])
	# Server should then broadcast roster to everyone if desired:
	if multiplayer.is_server():
		rpc("_sync_full_roster", players)

@rpc("any_peer", "reliable")
func _sync_full_roster(roster: Dictionary) -> void:
	players = roster.duplicate(true)
	# UI hook: update player list

# ---------- Host starts the real game ----------
# Host calls start_game_on_host; which will generate dungeon seed and notify clients
func start_game_on_host(map_scene_path: String) -> void:
	if not multiplayer.is_server():
		push_warning("Only host should call start_game_on_host()")
		return
	var seed = randi() # or compute properly
	# broadcast to all peers: load_game_scene with seed & map path
	rpc("_rpc_load_game_scene", seed, map_scene_path)

@rpc("any_peer", "reliable")
func _rpc_load_game_scene(seed: int, map_scene_path: String) -> void:
	# Each client loads the lobby map scene (or directly load the generated map scene)
	# We'll load a dedicated "map loader" scene which contains a DungeonGenerator3D and MapSpawner
	get_tree().change_scene_to_file(map_scene_path)
	# When the map scene is ready it should read the seed from Lobby (or accept it via Lobby)
	# Option: store the seed in Lobby so Map code can read it:
	Lobby._last_seed = seed
