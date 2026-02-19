extends Node3D

@export var player_scene: PackedScene

var spawn_points: Array[Node3D] = []
var used_spawns: Dictionary = {} # peer_id -> spawn_point

func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		spawn_player(peer_id)

func _ready():
	if multiplayer.is_server():
		collect_spawn_points()
		multiplayer.peer_connected.connect(_on_peer_connected)
		spawn_existing_players()

# -----------------------------------
# Setup
# -----------------------------------

func collect_spawn_points():
	for child in get_children():
		if child.is_in_group("SpawnPoint"):
			spawn_points.append(child)

func spawn_existing_players():
	for peer_id in multiplayer.get_peers():
		spawn_player(peer_id)
	# Also spawn host
	spawn_player(multiplayer.get_unique_id())


# -----------------------------------
# Spawn Logic
# -----------------------------------

func spawn_player(peer_id: int):
	var spawn = get_free_spawn_point()
	var player = player_scene.instantiate()
	player.name = str(peer_id)
	player.set_multiplayer_authority(peer_id)
	player.global_transform = spawn.global_transform
	add_child(player)
	# Send cosmetic setup
	#rpc("sync_player_cosmetics", peer_id, get_player_color(peer_id))

func get_free_spawn_point() -> Node3D:
	for spawn in spawn_points:
		if spawn not in used_spawns.values():
			return spawn
	return null
