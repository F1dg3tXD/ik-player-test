# Game.gd attached to root node named "Game"
extends Node3D

func _ready():
	# Tell server we're loaded and ready
	Lobby.player_loaded.rpc_id(1) # 1 is typically server
	
func start_game():
	print("Game start: server told us to begin")
	# enable gameplay, remove loading screen, etc.
