extends Node3D

@export var player_scene : PackedScene
@export var spawn_points_path : NodePath

var spawn_points : Array[Marker3D] = []

func _ready():
	if multiplayer.is_server():
		_collect_spawn_points()

		multiplayer.peer_connected.connect(_spawn_player)
		multiplayer.peer_disconnected.connect(_remove_player)

		# Spawn host
		_spawn_player(multiplayer.get_unique_id())

		# Spawn already connected clients
		for id in multiplayer.get_peers():
			_spawn_player(id)

func _collect_spawn_points():
	var container = get_node(spawn_points_path)
	for child in container.get_children():
		if child is Marker3D:
			spawn_points.append(child)

func _spawn_player(id: int):
	if has_node(str(id)):
		return # prevent duplicate spawns

	var player = player_scene.instantiate()
	player.name = str(id)
	player.set_multiplayer_authority(id)

	add_child(player)

	# Assign spawn position deterministically
	var index = id % spawn_points.size() if spawn_points.size() > 0 else 0
	player.global_transform = spawn_points[index].global_transform

func _remove_player(id: int):
	if has_node(str(id)):
		get_node(str(id)).queue_free()
