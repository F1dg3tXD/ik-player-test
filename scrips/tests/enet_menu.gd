extends Node2D

var peer : ENetMultiplayerPeer

@onready var btn_host: Button = $main/VBoxContainer/BTN_Host
@onready var btn_join: Button = $main/VBoxContainer/BTN_Join
@onready var id_prompt: LineEdit = $main/VBoxContainer/id_prompt

const PORT := 7777

func _ready() -> void:
	print("Menu ready")

func _on_btn_host_pressed() -> void:
	print("Starting ENet server...")
	
	peer = ENetMultiplayerPeer.new()
	var result = peer.create_server(PORT)
	
	if result != OK:
		print("Failed to create server:", result)
		return
	
	multiplayer.multiplayer_peer = peer
	
	print("Server started on port", PORT)
	get_tree().change_scene_to_file("res://maps/spawn_room.tscn")

func _on_btn_join_pressed() -> void:
	var ip = id_prompt.text.strip_edges()
	
	peer = ENetMultiplayerPeer.new()
	var result = peer.create_client(ip, PORT)
	
	if result != OK:
		print("Failed to create client:", result)
		return
	
	multiplayer.multiplayer_peer = peer
	
	multiplayer.connected_to_server.connect(_on_connected_to_server)

func _on_connected_to_server():
	print("Connected to host.")

func _on_id_prompt_text_changed(new_text):
	btn_join.disabled = (new_text.length() == 0)

@rpc("authority", "call_local")
func load_game_scene():
	get_tree().change_scene_to_file("res://maps/spawn_room.tscn")
