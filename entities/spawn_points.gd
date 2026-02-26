# spawn_points.gd
extends Node3D

@export var player_scene: PackedScene
@onready var players_parent: Node3D = $"../Players"

var player_spawn_markers: Array[Node3D] = []

func _ready():
	# Wait a couple frames to ensure map cells and groups are instantiated
	await get_tree().process_frame
	await get_tree().process_frame
	
	_collect_spawn_points()
	# SERVER: do NOT auto-spawn here.
	if multiplayer.is_server():
		print("[SpawnPoints] Server: collected %d spawn markers" % player_spawn_markers.size())
		return
	# CLIENT: wait until actually connected before notifying server
	print("[SpawnPoints] Client waiting for connected_to_server...")
	await multiplayer.connected_to_server
	print("[SpawnPoints] Client connected. Notifying server.")
	Lobby._notify_scene_ready.rpc_id(1)

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

func spawn_all_players():
	_spawn_players()

func _spawn_players():
	var peer_ids: Array = multiplayer.get_peers()
	peer_ids.append(multiplayer.get_unique_id()) # include host
	peer_ids.sort()
	print("[SpawnPoints] Spawning players. Peer order:", peer_ids)
	for i in range(peer_ids.size()):
		var peer_id: int = peer_ids[i]
		if i >= player_spawn_markers.size():
			push_warning("[SpawnPoints] Not enough player spawn markers! (%d players, %d markers)" % [peer_ids.size(), player_spawn_markers.size()])
			break
		var marker: Node3D = player_spawn_markers[i]
		var player = player_scene.instantiate()
		player.name = str(peer_id)
		player.global_transform = marker.global_transform
		# IMPORTANT: add first, then set authority
		players_parent.add_child(player)
		player.set_multiplayer_authority(peer_id)
		print("[SpawnPoints] Spawned player %s at marker %d." % [str(peer_id), i])
