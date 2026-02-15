extends Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Console.pause_enabled = true
	Console.console_opened.connect(on_console_opened)
	Console.console_closed.connect(on_console_closed)
	Console.add_command("debug", on_debug, 1, 1, "debug 1 = show debug nodes, debug 0 = hide debug nodes")
	Console.add_command("fly", on_fly, 1, 1, "fly 1 = fly, fly 0 = no fly")

func _exit_tree() -> void:
	Console.remove_command("debug")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func on_console_opened():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func on_console_closed():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
func on_debug(param: String) -> void:
	var enabled: bool = param.to_int() != 0

	for node in get_tree().get_nodes_in_group("Debug"):
		if node is Node3D:
			node.visible = enabled
		elif node is CanvasItem:
			node.visible = enabled

func on_fly(param: String) -> void:
	var fly_enabled: bool = param.to_int() != 0
	
	for node in get_tree().get_nodes_in_group("Player"):
		if node is CharacterBody3D:
			if fly_enabled:
				node.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
			else:
				node.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
			
			# Optional: call a function on the player
			if node.has_method("set_fly_mode"):
				node.set_fly_mode(fly_enabled)
