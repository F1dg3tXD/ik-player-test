extends Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Console.pause_enabled = true
	Console.console_opened.connect(on_console_opened)
	Console.console_closed.connect(on_console_closed)
	Console.add_command("debug", on_debug, 1, 1, "debug 1 = show debug nodes, debug 0 = hide debug nodes")

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
