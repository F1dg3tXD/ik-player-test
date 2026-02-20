extends Node
@onready var camera = $"../neck/head/Camera3D"

## INFO: Here is all the other things that need to be synced, other then movement

func _ready():
	camera.current = is_multiplayer_authority()
