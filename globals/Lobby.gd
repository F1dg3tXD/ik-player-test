extends Node

signal lobby_created(room_code: String)
signal lobby_joined(room_code: String)

@onready var _scene_tree := get_tree()

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)

func host_webrtc_lobby(room_code: String, signaling_url: String) -> Error:
	var result := NetworkManager.start_webrtc_host(room_code, signaling_url)
	if result != OK:
		return result
	await _scene_tree.process_frame
	_spawn_player(multiplayer.get_unique_id())
	_hide_menu()
	emit_signal("lobby_created", room_code)
	return OK

func join_webrtc_lobby(room_code: String, signaling_url: String) -> Error:
	var result := NetworkManager.start_webrtc_client(room_code, signaling_url)
	if result != OK:
		return result
	emit_signal("lobby_joined", room_code)
	return OK

func _on_connected_to_server() -> void:
	_hide_menu()

func _on_peer_connected(id: int) -> void:
	if not multiplayer.is_server():
		return
	_spawn_player(id)

func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	var spawn := _get_spawn_points_node()
	if spawn:
		spawn.despawn_player(id)

func _spawn_player(peer_id: int) -> void:
	var spawn := _get_spawn_points_node()
	if spawn:
		spawn.spawn_player(peer_id)

func _get_spawn_points_node() -> Node:
	var scene := _scene_tree.current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("spawnPoints")

func _hide_menu() -> void:
	var scene = _scene_tree.current_scene
	if scene == null:
		return
	var menu = scene.get_node_or_null("Cameras/MenuCamera/Menu")
	if menu:
		menu.visible = false
