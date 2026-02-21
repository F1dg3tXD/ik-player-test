extends MultiplayerSpawner

@export var player_scene : PackedScene

@export_category("Configurations")
@export var spawn_points_path : NodePath
var spawn_points : Array[Node3D] = []

## This is for spawning that only happens once, if a player spawns in that location, no one else can spawn there.
@export var spawn_in_empty : bool

var players = {}

## INFO: When host connects, peer_connected -> spawn method from the player_spawner (so we don't instance multiple maps)

func _ready():
	spawn_function = spawn_player
	
	if is_multiplayer_authority():
		call_deferred("_setup_spawning")
		
func _setup_spawning():
	await get_tree().process_frame
	await get_tree().process_frame  # two frames for safety
	
	collect_spawn_points()
	spawn(multiplayer.get_unique_id())
	multiplayer.peer_connected.connect(spawn)
	multiplayer.peer_disconnected.connect(remove_player)
	
func collect_spawn_points():
	spawn_points.clear()
	var container = get_node(spawn_points_path)
	for child in container.get_children():
		if child is Node3D:
			spawn_points.append(child)
	
func spawn_player(data):
	var player : CharacterBody3D = player_scene.instantiate()
	player.set_multiplayer_authority(data)
	players[data] = player
	
	var spawn_position : Vector3 = Vector3.ZERO
	
	if spawn_in_empty:
		for spawn_point : Node3D in spawn_points:
			if spawn_point.get_child_count() == 0:
				spawn_position = spawn_point.global_position
				spawn_point.add_child(Node3D.new())
				break
	
	player.position = spawn_position
	return player
	
func remove_player(data):
	players[data].queue_free()
	players.erase(data)
