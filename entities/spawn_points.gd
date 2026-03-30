extends Node3D

@export var player_scene: PackedScene
@onready var players_parent: Node3D = $"../Players"

var spawn_markers: Array[Node3D] = []
var _pending_spawns: Array[int] = []

func _ready() -> void:
	_collect_spawn_markers()
	for peer_id in _pending_spawns:
		spawn_player(peer_id)
	_pending_spawns.clear()

func _collect_spawn_markers() -> void:
	spawn_markers.clear()
	for child in get_children():
		if child is Node3D and child.is_in_group("PlayerSpawn"):
			spawn_markers.append(child)
	print("Spawn markers:", spawn_markers.size())

func spawn_player(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if spawn_markers.is_empty():
		_pending_spawns.append(peer_id)
		push_warning("No spawn markers configured yet. Queued spawn for peer %s." % peer_id)
		return
	if players_parent.has_node(str(peer_id)):
		return
	var index := players_parent.get_child_count() % spawn_markers.size()
	var marker := spawn_markers[index]
	_spawn_player_rpc.rpc(peer_id, marker.global_transform)

func despawn_player(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	_despawn_player_rpc.rpc(peer_id)

@rpc("authority", "call_local", "reliable")
func _spawn_player_rpc(peer_id: int, spawn_transform: Transform3D) -> void:
	if players_parent.has_node(str(peer_id)):
		return
	var player := player_scene.instantiate()
	player.name = str(peer_id)
	players_parent.add_child(player)
	player.set_multiplayer_authority(peer_id)
	player.global_transform = spawn_transform
	print("Spawned player:", peer_id)

@rpc("authority", "call_local", "reliable")
func _despawn_player_rpc(peer_id: int) -> void:
	var node := players_parent.get_node_or_null(str(peer_id))
	if node:
		node.queue_free()
