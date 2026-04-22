extends Node3D

var _players_parent: Node3D
var _pause_menu: CanvasLayer
var _pause_panel: PanelContainer
var _room_code_value: LineEdit
var _copy_room_code_button: Button
var _pause_status_label: Label
var _menu: Node2D
var _lobby_node: Node

func _ready() -> void:
	_pause_menu = get_node_or_null("PauseMenu")
	if _pause_menu:
		_pause_panel = _pause_menu.get_node_or_null("PausePanel")
		if _pause_panel:
			var vbox = _pause_panel.get_node_or_null("VBoxContainer")
			if vbox:
				_room_code_value = vbox.get_node_or_null("RoomCodeRow/RoomCodeValue")
				_copy_room_code_button = vbox.get_node_or_null("CopyRoomCodeButton")
				_pause_status_label = vbox.get_node_or_null("StatusLabel")
		_pause_menu.visible = false

	_menu = get_node_or_null("Menu")

	_get_players_parent()

	if multiplayer.is_server():
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	_update_pause_menu_for_role()
	_lobby_node = get_tree().root.get_node_or_null("Lobby")
	if _lobby_node:
		_lobby_node.lobby_created.connect(_on_lobby_state_updated)
		_lobby_node.lobby_joined.connect(_on_lobby_state_updated)

func _get_players_parent() -> Node3D:
	if _players_parent and is_instance_valid(_players_parent):
		return _players_parent
	var root = get_tree().root
	if root.has_node("World/Players"):
		_players_parent = root.get_node("World/Players")
	return _players_parent

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle_pause_menu()

func _toggle_pause_menu() -> void:
	if _pause_menu == null:
		return
	_pause_menu.visible = not _pause_menu.visible
	if _pause_menu.visible:
		_update_pause_menu_for_role()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _update_pause_menu_for_role() -> void:
	if _pause_status_label == null:
		return
	
	var room_code_val := ""
	if _lobby_node != null:
		var ac = _lobby_node.get("active_room_code")
		if ac != null:
			room_code_val = ac
	
	if room_code_val.is_empty():
		room_code_val = "(No lobby room code available)"
	if _room_code_value:
		_room_code_value.text = room_code_val

	var can_copy: bool = multiplayer.is_server()
	if _lobby_node != null and _lobby_node.has_method("_is_dedicated_server_mode"):
		var is_dedicated: bool = _lobby_node.call("_is_dedicated_server_mode")
		can_copy = can_copy and not is_dedicated
	if _copy_room_code_button:
		_copy_room_code_button.visible = can_copy
	if _room_code_value:
		_room_code_value.editable = false

	if can_copy:
		_pause_status_label.text = "Host room code available for sharing."
	else:
		_pause_status_label.text = "Room code copy is host-only."

func _on_copy_room_code_button_pressed() -> void:
	if _lobby_node != null:
		var ac = _lobby_node.get("active_room_code")
		if ac != null and ac != "":
			DisplayServer.clipboard_set(ac)
			_pause_status_label.text = "Room code copied to clipboard."
			return
	_pause_status_label.text = "No room code to copy yet."

func _on_lobby_state_updated(_room_code: String) -> void:
	_update_pause_menu_for_role()

func _on_peer_disconnected(id: int):
	if multiplayer.is_server():
		var parent := _get_players_parent()
		if parent:
			var player = parent.get_node_or_null(str(id))
			if player:
				player.queue_free()
