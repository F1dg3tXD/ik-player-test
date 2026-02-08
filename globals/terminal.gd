extends Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Console.console_opened.connect(on_console_opened)
	Console.console_closed.connect(on_console_closed)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func on_console_opened():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func on_console_closed():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
