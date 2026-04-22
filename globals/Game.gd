# Game.gd attached to root node named "Game"
extends Node3D

func _ready() -> void:
	var lobby = get_tree().root.get_node_or_null("Lobby")
	if lobby and lobby.has_method("player_loaded"):
		lobby.player_loaded.rpc_id(1)
	
func start_game() -> void:
	print("Game start: server told us to begin")