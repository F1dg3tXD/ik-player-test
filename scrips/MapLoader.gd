# MapLoader.gd
extends Node3D

@onready var dungeon = $DungeonGenerator3D
@onready var game_manager = $GameManager

func _ready() -> void:
	var genSeed = Lobby._last_seed
	
	# Connect BEFORE generating
	dungeon.done_generating.connect(_on_generation_finished)
	
	dungeon.generate(genSeed)


func _on_generation_finished() -> void:
	# IMPORTANT: Wait one frame to ensure all generated nodes are fully added
	await get_tree().process_frame
	
	game_manager.initialize_after_generation()
