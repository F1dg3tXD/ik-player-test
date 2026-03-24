extends Node3D

@onready var players_parent: Node3D = $Players
@onready var menu: Node2D = $Cameras/MenuCamera/Menu
@onready var pause_menu: CanvasLayer = $PauseMenu
@onready var pause_panel: PanelContainer = $PauseMenu/PausePanel
@onready var room_code_value: LineEdit = $PauseMenu/PausePanel/VBoxContainer/RoomCodeRow/RoomCodeValue
@onready var copy_room_code_button: Button = $PauseMenu/PausePanel/VBoxContainer/CopyRoomCodeButton
@onready var pause_status_label: Label = $PauseMenu/PausePanel/VBoxContainer/StatusLabel

func _ready():
	if multiplayer.is_server():
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	pause_menu.visible = false
	_update_pause_menu_for_role()
	Lobby.lobby_created.connect(_on_lobby_state_updated)
	Lobby.lobby_joined.connect(_on_lobby_state_updated)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle_pause_menu()

func _toggle_pause_menu() -> void:
	pause_menu.visible = not pause_menu.visible
	if pause_menu.visible:
		_update_pause_menu_for_role()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _update_pause_menu_for_role() -> void:
	var room_code := Lobby.active_room_code
	if room_code.is_empty():
		room_code = "(No lobby room code available)"
	room_code_value.text = room_code

	var can_copy_room_code := multiplayer.is_server() and not Lobby._is_dedicated_server_mode()
	copy_room_code_button.visible = can_copy_room_code
	room_code_value.editable = false

	if can_copy_room_code:
		pause_status_label.text = "Host room code available for sharing."
	else:
		pause_status_label.text = "Room code copy is host-only."

func _on_copy_room_code_button_pressed() -> void:
	if Lobby.active_room_code.is_empty():
		pause_status_label.text = "No room code to copy yet."
		return
	DisplayServer.clipboard_set(Lobby.active_room_code)
	pause_status_label.text = "Room code copied to clipboard."

func _on_lobby_state_updated(_room_code: String) -> void:
	_update_pause_menu_for_role()

func _on_peer_disconnected(id: int):
	if multiplayer.is_server():
		var player = players_parent.get_node_or_null(str(id))
		if player:
			player.queue_free()
