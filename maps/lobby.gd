# Lobby Map Script
extends Node3D
#
#@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner
@onready var spawn_points_parent: Node3D = $spawnPoints
@onready var players_parent: Node3D = $Players

var spawn_points: Array[Marker3D] = []

func _ready():
	for child in spawn_points_parent.get_children():
		if child is Marker3D:
			spawn_points.append(child)
		
	if multiplayer.is_server():
		#multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		

func _on_peer_disconnected(id: int):
	if multiplayer.is_server():
		var player = players_parent.get_node_or_null(str(id))
		if player:
			player.queue_free()
