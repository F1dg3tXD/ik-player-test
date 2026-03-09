# spawn_points.gd
extends Node3D

signal spawn_points_ready
@export var player_scene: PackedScene
@onready var players_parent: Node3D = $"../Players"

var player_spawn_markers: Array[Node3D] = []

func _ready():
	# Wait a couple frames to ensure map cells and groups are instantiated
	await get_tree().process_frame
	await get_tree().process_frame
	
	_collect_spawn_points()
	# SERVER: do NOT auto-spawn here.
	
	if not multiplayer.is_server():
		print("[SpawnPoints] Client scene ready")
		Lobby.client_scene_ready.rpc_id(1)
	
	if multiplayer.is_server():
		print("[SpawnPoints] Server: collected %d spawn markers" % player_spawn_markers.size())
		return
	# CLIENT: wait until actually connected before notifying server
	print("[SpawnPoints] Client waiting for connected_to_server...")
	if not multiplayer.is_server():
		await multiplayer.connected_to_server
		print("[SpawnPoints] Client ready -> notifying server")
		Lobby.client_scene_ready.rpc_id(1)
	emit_signal("spawn_points_ready")

# --------------------------------------------------
# Collect Spawn Markers From Entire Map
# --------------------------------------------------

func _collect_spawn_points():
	player_spawn_markers.clear()
	for marker in get_tree().get_nodes_in_group("PlayerSpawn"):
		if marker is Node3D:
			player_spawn_markers.append(marker)
	print("[SpawnPoints] Found %d PlayerSpawn markers." % player_spawn_markers.size())

# --------------------------------------------------
# Players
# --------------------------------------------------

func spawn_player(peer_id:int):
	if not multiplayer.is_server():
		print("[SpawnPoints] Client scene ready")
		Lobby.client_scene_ready.rpc_id(1)
	# Prevent duplicate players
	if players_parent.has_node(str(peer_id)):
		return
	var index := players_parent.get_child_count()
	if index >= player_spawn_markers.size():
		push_warning("[SpawnPoints] Not enough spawn markers! (%d players, %d markers)" % [index, player_spawn_markers.size()])
		return
	var marker: Node3D = player_spawn_markers[index]
	var player = player_scene.instantiate()
	player.name = str(peer_id)
	players_parent.add_child(player)
	player.set_multiplayer_authority(peer_id)
	player.global_transform = marker.global_transform
	print("[SpawnPoints] Spawned player %s at marker %d" % [peer_id, index])
	
