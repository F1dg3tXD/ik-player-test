# spawn_points.gd
extends Node3D

@export var player_scene: PackedScene
#@export var npc_scene: PackedScene
#@export var item_scene: PackedScene

@onready var players_parent: Node3D = $"../Players"
#@onready var npc_parent: Node3D = $"../NPCs"
#@onready var item_parent: Node3D = $"../Items"

var player_spawn_markers: Array[Node3D] = []
#var npc_spawn_markers: Array[Marker3D] = []
#var item_spawn_markers: Array[Marker3D] = []

func _ready():
	# Wait a couple frames to ensure map cells and groups are instantiated
	await get_tree().process_frame
	await get_tree().process_frame
	_collect_spawn_points()
	# If server: do NOT auto-spawn here — Lobby will call spawn_all_players() once everyone is ready.
	if multiplayer.is_server():
		print("[SpawnPoints] Server: collected %d spawn markers" % player_spawn_markers.size())
		return
	# Client: ensure the multiplayer peer is connected before notifying server.
	var status: MultiplayerPeer.ConnectionStatus = multiplayer.get_connection_status()
	if int(status) != MultiplayerPeer.CONNECTION_CONNECTED:
		# Wait for the connected_to_server signal (or timeout)
		print("[SpawnPoints] Client: waiting for connection...")
		await multiplayer.connected_to_server
		print("[SpawnPoints] Client: connected_to_server signal received.")
	# Now we can safely tell the server we're ready
	print("[SpawnPoints] Client: notifying server that this client finished loading the map.")
	# rpc_id will work because we waited for a connection
	Lobby._notify_scene_ready.rpc_id(1)

# --------------------------------------------------
# Collect Spawn Markers From Entire Map
# --------------------------------------------------

func _collect_spawn_points():
	player_spawn_markers.clear()
	for marker in get_tree().get_nodes_in_group("PlayerSpawn"):
		# ensure we store Node3D (Marker3D) references only
		if marker is Node3D:
			player_spawn_markers.append(marker)
	print("[SpawnPoints] Found %d PlayerSpawn markers." % player_spawn_markers.size())

	# Collect NPC spawn markers (all cells)
	#for marker in get_tree().get_nodes_in_group("NPCSpawn"):
		#npc_spawn_markers.append(marker)

	# Collect item spawn markers (all cells)
	#for marker in get_tree().get_nodes_in_group("ItemSpawn"):
		#item_spawn_markers.append(marker)


# --------------------------------------------------
# Players
# --------------------------------------------------

func spawn_all_players():
	_spawn_players()

func _spawn_players():
	var peer_ids: Array = multiplayer.get_peers()
	# include host
	peer_ids.append(multiplayer.get_unique_id())

	# deterministic ordering
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

		# add to scene first, then set authority
		players_parent.add_child(player)
		player.set_multiplayer_authority(peer_id)

		print("[SpawnPoints] Spawned player %s at marker %d." % [str(peer_id), i])

# --------------------------------------------------
# NPCs
# --------------------------------------------------

#func _spawn_npcs():
#
	#for marker in npc_spawn_markers:
#
		#if randf() < 0.6: # 60% chance to spawn
			#var npc = npc_scene.instantiate()
			#npc.global_transform = marker.global_transform
			#npc_parent.add_child(npc)


# --------------------------------------------------
# Items
# --------------------------------------------------

#func _spawn_items():
#
	#for marker in item_spawn_markers:
#
		#if randf() < 0.5:
			#var item = item_scene.instantiate()
			#item.global_transform = marker.global_transform
			#item_parent.add_child(item)
