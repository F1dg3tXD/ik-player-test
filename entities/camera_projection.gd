extends SubViewport
@onready var camera_3d: Camera3D = $Camera3D

func _ready() -> void:
	camera_3d.cull_mask = 0xFFFFFFFF
