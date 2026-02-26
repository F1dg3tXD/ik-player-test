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
	if not multiplayer.is_server():
		return
	await get_tree().process_frame
	await get_tree().process_frame
	_collect_spawn_points()
	#_spawn_npcs()
	#_spawn_items()
	if not multiplayer.is_server():
		Lobby._notify_scene_ready.rpc_id(1)


# --------------------------------------------------
# Collect Spawn Markers From Entire Map
# --------------------------------------------------

func _collect_spawn_points():

	# Collect player spawn markers (inside spawn_room)
	for marker in get_tree().get_nodes_in_group("PlayerSpawn"):
		player_spawn_markers.append(marker)

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
	
	var peer_ids = multiplayer.get_peers()
	peer_ids.append(multiplayer.get_unique_id()) # include host
	
	peer_ids.sort()
	
	for i in range(peer_ids.size()):
		var peer_id = peer_ids[i]
		
		if i >= player_spawn_markers.size():
			push_warning("Not enough player spawn markers!")
			break
		
		var marker = player_spawn_markers[i]
		print("Spawn markers:", player_spawn_markers.size())
		print("Spawning players:", peer_ids)
		
		var player = player_scene.instantiate()
		player.name = str(peer_id)
		player.global_transform = marker.global_transform
		player.set_multiplayer_authority(peer_id)
		
		players_parent.add_child(player)

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
