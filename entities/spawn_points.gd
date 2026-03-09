extends Node3D

@export var player_scene:PackedScene
@onready var players_parent:Node3D = $"../Players"

var spawn_markers:Array[Node3D] = []

func _ready():
	await get_tree().process_frame
	await get_tree().process_frame
	for marker in get_tree().get_nodes_in_group("PlayerSpawn"):
		if marker is Node3D:
			spawn_markers.append(marker)
	print("Spawn markers:",spawn_markers.size())

func spawn_player(peer_id:int):
	if not multiplayer.is_server():
		return
	if players_parent.has_node(str(peer_id)):
		return
	var index := players_parent.get_child_count()
	if index >= spawn_markers.size():
		push_warning("Not enough spawn markers")
		return
	var marker := spawn_markers[index]
	var player = player_scene.instantiate()
	player.name = str(peer_id)
	players_parent.add_child(player)
	player.set_multiplayer_authority(peer_id)
	player.global_transform = marker.global_transform
	print("Spawned player:",peer_id)
