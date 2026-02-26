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
func _on_steam_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, _response: int) -> void:
	
	await get_tree().process_frame  # wait 1 frame
	
	var host_id = Steam.getLobbyOwner(lobby_id)
	var my_id = Steam.getSteamID()
	
	print("My ID:", my_id)
	print("Host ID:", host_id)
	
	if host_id == 0:
		print("Steam not ready, waiting...")
		await get_tree().create_timer(0.2).timeout
		host_id = Steam.getLobbyOwner(lobby_id)
		
	if my_id == host_id:
		emit_signal("lobby_joined", lobby_id)
		NetworkManager.start_steam_host()
	else:
		emit_signal("lobby_joined", lobby_id)
		NetworkManager.start_steam_client(host_id)
		# Have to load the Lobby map on the client first
		get_tree().change_scene_to_file("res://maps/Lobby.tscn")
	

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
	
# ---------- Scene: default loader ----------
func start_simple_scene(map_scene_path: String) -> void:
	# Only server should invoke this shortcut.
	if not multiplayer.is_server():
		return
	_last_seed = 0
	# Host loads the simple scene for themselves and tells clients to load it
	_rpc_load_simple_scene(map_scene_path)
	rpc("_rpc_load_simple_scene", map_scene_path)
	
func _check_all_ready():
	var peer_ids = multiplayer.get_peers()
	peer_ids.append(multiplayer.get_unique_id())
	print("[Lobby] players_ready:", players_ready, " peers:", peer_ids)
	for id in peer_ids:
		if not players_ready.has(id):
			print("[Lobby] Waiting for peer %s to be ready..." % str(id))
			return
	print("[Lobby] All players ready — instructing SpawnPoints to spawn players")
	var spawn_node: Node = get_tree().get_current_scene().get_node_or_null("spawnPoints")
	if not spawn_node:
		push_error("[Lobby] spawnPoints node not found in current scene.")
		return
	# Tell spawn node to spawn (server-only)
	if multiplayer.is_server():
		spawn_node.spawn_all_players()

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
	# UI hook: update player list

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
	# Host executes local load (so host runs the same logic as clients)
	_rpc_load_game_scene(dungeon_seed, map_scene_path) # runs locally
	# Then tell clients to load
	rpc("_rpc_load_game_scene", dungeon_seed, map_scene_path)

@rpc("any_peer", "reliable")
func _rpc_load_game_scene(dungeon_seed: int, map_scene_path: String) -> void:
	# Store the seed for the map loader to read
	_last_seed = dungeon_seed
	players_ready.clear()
	print("[Lobby] Loading map scene:", map_scene_path, " seed:", dungeon_seed)
	get_tree().change_scene_to_file(map_scene_path)
	# Host marks itself ready; clients will notify via Lobby._notify_scene_ready
	if multiplayer.is_server():
		players_ready[multiplayer.get_unique_id()] = true
		# allow one frame so SpawnPoints can collect markers
		await get_tree().process_frame
		_check_all_ready()
	
@rpc("any_peer", "reliable")
func _rpc_load_simple_scene(map_scene_path: String) -> void:
	print("[Lobby] _rpc_load_simple_scene -> loading:", map_scene_path)
	get_tree().change_scene_to_file(map_scene_path)
	
@rpc("any_peer", "reliable")
func _notify_scene_ready() -> void:
	var sender := multiplayer.get_remote_sender_id()
	print("[Lobby] _notify_scene_ready received from:", sender)
	players_ready[sender] = true
	if multiplayer.is_server():
		_check_all_ready()
