extends Node

var peer : ENetMultiplayerPeer
const PORT := 7777

func host_game():
	peer = ENetMultiplayerPeer.new()
	var result = peer.create_server(PORT)

	if result != OK:
		print("Failed to create server:", result)
		return

	multiplayer.multiplayer_peer = peer
	print("Server started.")
	load_game_scene.rpc()

func join_game(ip: String):
	peer = ENetMultiplayerPeer.new()
	var result = peer.create_client(ip, PORT)

	if result != OK:
		print("Failed to connect:", result)
		return

	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected)

func _on_connected():
	print("Connected to host.")
	load_game_scene.rpc()

@rpc("authority", "call_local")
func load_game_scene():
	get_tree().change_scene_to_file("res://maps/spawn_room.tscn")
