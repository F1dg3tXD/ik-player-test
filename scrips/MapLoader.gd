# MapLoader.gd
extends Node3D

@onready var dungeon = $DungeonGenerator3D
@onready var game_manager = $GameManager

var _last_seed: int = 0

func _ready() -> void:
	var lobby = get_tree().root.get_node_or_null("Lobby")
	if lobby and lobby.has("_last_seed"):
		_last_seed = lobby.get("_last_seed")
	else:
		_last_seed = randi()
	
	dungeon.done_generating.connect(_on_generation_finished)
	
	dungeon.generate(_last_seed)


func _on_generation_finished() -> void:
	await get_tree().process_frame
	
	game_manager.initialize_after_generation()