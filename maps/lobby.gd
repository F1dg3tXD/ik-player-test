extends Node3D

@onready var players_parent: Node3D = $Players
@onready var menu: Node2D = $Cameras/MenuCamera/Menu

func _ready():
	if multiplayer.is_server():
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _on_peer_disconnected(id: int):
	if multiplayer.is_server():
		var player = players_parent.get_node_or_null(str(id))
		if player:
			player.queue_free()
