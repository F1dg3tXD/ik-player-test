extends Node3D

@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner
@onready var spawn_points_parent: Node3D = $spawnPoints
@onready var players_parent: Node3D = $Players

var spawn_points: Array[Marker3D] = []

func _ready():
	for child in spawn_points_parent.get_children():
		if child is Marker3D:
			spawn_points.append(child)
		
	if multiplayer.is_server():
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		
		_spawn_player(multiplayer.get_unique_id())

func _on_peer_connected(id: int):
	if multiplayer.is_server():
		_spawn_player(id)


func _on_peer_disconnected(id: int):
	if multiplayer.is_server():
		var player = players_parent.get_node_or_null(str(id))
		if player:
			player.queue_free()


func _spawn_player(peer_id: int):
	if peer_id > spawn_points.size():
		push_warning("Not enough spawn points!")
		return
	
	var spawn_transform = spawn_points[peer_id - 1].global_transform
	
	var player_scene = preload("res://player.tscn")
	var player = player_scene.instantiate()
	
	player.name = str(peer_id)
	player.global_transform = spawn_transform
	player.set_multiplayer_authority(peer_id)
	
	players_parent.add_child(player)
