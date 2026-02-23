extends Node3D

@export var player_scene : PackedScene

var spawn_points : Array = []

func initialize_after_generation() -> void:
	_collect_spawn_points()

	if spawn_points.is_empty():
		push_error("NO SPAWN POINTS FOUND! Check group name.")
		return

	# Only server spawns
	if multiplayer.is_server():
		_spawn_existing_players()

		# Listen for late joiners
		multiplayer.peer_connected.connect(_on_peer_connected)


func _collect_spawn_points() -> void:
	spawn_points.clear()

	for node in get_tree().get_nodes_in_group("SpawnPoints"):
		spawn_points.append(node)

	print("Collected spawn points: ", spawn_points.size())


func _spawn_existing_players() -> void:
	_spawn_player(multiplayer.get_unique_id())

	for id in multiplayer.get_peers():
		_spawn_player(id)


func _on_peer_connected(id: int) -> void:
	_spawn_player(id)


func _spawn_player(id: int) -> void:
	# Prevent double spawning
	if has_node(str(id)):
		return

	if spawn_points.is_empty():
		push_error("Spawn points empty when trying to spawn.")
		return

	var spawn_index = id % spawn_points.size()
	var spawn_transform = spawn_points[spawn_index].global_transform

	var player = player_scene.instantiate()
	player.name = str(id)
	player.set_multiplayer_authority(id)

	add_child(player)
	player.global_transform = spawn_transform
