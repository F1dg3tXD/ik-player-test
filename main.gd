extends Node2D

var lobby_id : int = 0
var peer : SteamMultiplayerPeer
@export var player_scene : PackedScene
var is_host : bool = false
var is_joining : bool = false

@onready var btn_host: Button = $main/VBoxContainer/BTN_Host
@onready var btn_join: Button = $main/VBoxContainer/BTN_Join
@onready var id_prompt: LineEdit = $main/VBoxContainer/id_prompt

func host_lobby():
	Steam.createLobby(Steam.LobbyType.LOBBY_TYPE_PUBLIC, 16)
	
func join_lobby(target_lobby_id: int):
	is_joining = true
	Steam.joinLobby(target_lobby_id)

	
func _on_lobby_joined(new_lobby_id : int, _permissions : int, _locked: bool, _response: int):
	if !is_joining:
		return
	
	lobby_id = new_lobby_id
	
	self.lobby_id = lobby_id
	peer = SteamMultiplayerPeer.new()
	peer.server_relay = true
	peer.create_client(Steam.getLobbyOwner(lobby_id))
	multiplayer.multiplayer_peer = peer
	
	multiplayer.connected_to_server.connect(_on_connected_to_server)

	is_joining = false
	
func _on_connected_to_server():
	print("Connected to host.")

	
func _on_lobby_created(result: int, new_lobby_id: int):
	print("Lobby created callback fired. Result:", result)
	if result == Steam.Result.RESULT_OK:
		print("Lobby creation successful")
		lobby_id = new_lobby_id
		
		peer = SteamMultiplayerPeer.new()
		peer.server_relay = true
		peer.create_host()
		
		multiplayer.multiplayer_peer = peer
		
		print("Lobby Created, lobby id: ", lobby_id)
		# Host tells everyone to load the game
		load_game_scene.rpc()

func _ready() -> void:
	print("Steam running:", Steam.isSteamRunning())
	Steam.initRelayNetworkAccess()
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)

func _process(_delta):
	Steam.run_callbacks()

func _on_btn_host_pressed() -> void:
	print("Host button pressed")
	host_lobby()

func _on_id_prompt_text_changed(new_text):
	btn_join.disabled = (new_text.length() == 0)

@rpc("any_peer", "call_local")
func load_game_scene():
	get_tree().change_scene_to_file("res://maps/spawn_room.tscn")

func _on_btn_join_pressed() -> void:
	join_lobby(id_prompt.text.to_int())
