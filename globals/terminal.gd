extends Node

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Console.pause_enabled = false
	Console.console_opened.connect(on_console_opened)
	Console.console_closed.connect(on_console_closed)
	Console.add_command("debug", on_debug, 1, 1, "debug 0 = off | debug 1 = debug nodes | debug 2 = nav paths + avoidance")
	Console.add_command("fly", on_fly, 1, 1, "fly 1 = fly, fly 0 = no fly")

func _exit_tree() -> void:
	Console.remove_command("debug")

func on_console_opened():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func on_console_closed():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
func on_debug(param: String) -> void:
	var level := param.to_int()
	# Level 0 - Everything Off
	if level <= 0:
		set_debug_nodes(false)
		set_navigation_debug(false)
		return
	# Level 1 - Debug Nodes Only
	if level == 1:
		set_debug_nodes(true)
		set_navigation_debug(false)
		return
	# Level 2 - Full Nav Debug
	if level >= 2:
		set_debug_nodes(true)
		set_navigation_debug(true)
		return
		
func set_debug_nodes(enabled: bool) -> void:
	for node in get_tree().get_nodes_in_group("Debug"):
		if node is Node3D or node is CanvasItem:
			node.visible = enabled

func set_navigation_debug(enabled: bool) -> void:
	for agent in get_tree().get_nodes_in_group("WeepingAngel"):
		if agent.has_node("NavigationAgent3D"):
			var nav = agent.get_node("NavigationAgent3D")
			nav.debug_enabled = enabled

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
