extends Node3D

@export var player_scene : PackedScene
@export var spawn_points_path : NodePath

var spawn_points : Array[Marker3D] = []

func _ready():
	_collect_spawn_points()

	if multiplayer.is_server():
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_remove_player)

		# Delay one frame to ensure peers are registered
		call_deferred("_spawn_existing_players")

func _collect_spawn_points():
	var container = get_node(spawn_points_path)
	for child in container.get_children():
		if child is Marker3D:
			spawn_points.append(child)

func _spawn_existing_players():
	# Spawn host
	_spawn_player(multiplayer.get_unique_id())

	# Spawn already connected clients
	for id in multiplayer.get_peers():
		_spawn_player(id)

func _on_peer_connected(id: int):
	print("Peer connected:", id)
	_spawn_player(id)
	
@rpc("authority", "call_local")
func _spawn_player_rpc(id: int, spawn_transform: Transform3D):
	if has_node(str(id)):
		return

	var player = player_scene.instantiate()
	player.name = str(id)
	player.set_multiplayer_authority(id)
	player.global_transform = spawn_transform

	add_child(player)

func _spawn_player(id: int):
	if has_node(str(id)):
		return

	if spawn_points.is_empty():
		push_error("No spawn points!")
		return

	var index = abs(id) % spawn_points.size()
	var spawn_transform = spawn_points[index].global_transform

	_spawn_player_rpc(id, spawn_transform)

func _remove_player(id: int):
	if has_node(str(id)):
		print("Client saw nothing but grey and left")
		get_node(str(id)).queue_free()
