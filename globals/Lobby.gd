extends Node

signal lobby_created(room_code: String)
signal lobby_joined(room_code: String)

const DEDICATED_SERVER_FLAG := "-server"

@onready var _scene_tree := get_tree()

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)

	if _is_dedicated_server_mode():
		call_deferred("_start_dedicated_server")

func host_webrtc_lobby(room_code: String, signaling_url: String) -> Error:
	var result := NetworkManager.start_webrtc_host(room_code, signaling_url)
	if result != OK:
		return result
	await _scene_tree.process_frame
	_spawn_player(NetworkManager.get_local_peer_id())
	_hide_menu()
	emit_signal("lobby_created", room_code)
	return OK

func join_webrtc_lobby(room_code: String, signaling_url: String) -> Error:
	var result := NetworkManager.start_webrtc_client(room_code, signaling_url)
	if result != OK:
		return result
	emit_signal("lobby_joined", room_code)
	return OK

func _start_dedicated_server() -> void:
	var room_code := _get_dedicated_arg_value("-room=", "default")
	var signaling_url := _get_dedicated_arg_value("-signaling-url=", NetworkManager.DEFAULT_SIGNALING_URL)
	var result := await host_webrtc_lobby(room_code, signaling_url)
	if result != OK:
		push_error("[Dedicated Server] Failed to start host (%s) using %s" % [result, signaling_url])
		return

	print("[Dedicated Server] Started room '%s' with signaling URL %s" % [room_code, signaling_url])
	print("[Dedicated Server] Server peer ID: %s" % NetworkManager.get_local_peer_id())
	print("[Dedicated Server] Waiting for players to connect...")

func _is_dedicated_server_mode() -> bool:
	for arg in OS.get_cmdline_args():
		if arg == DEDICATED_SERVER_FLAG:
			return true
	return false

func _get_dedicated_arg_value(prefix: String, fallback: String) -> String:
	for arg in OS.get_cmdline_args():
		if arg.begins_with(prefix):
			var value := arg.trim_prefix(prefix).strip_edges()
			if not value.is_empty():
				return value
	return fallback

func _on_connected_to_server() -> void:
	_hide_menu()

func _on_peer_connected(id: int) -> void:
	if not multiplayer.is_server():
		return
	print("[Dedicated Server] Player connected: %s" % id)
	_spawn_player(id)

func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	print("[Dedicated Server] Player disconnected: %s" % id)
	var spawn := _get_spawn_points_node()
	if spawn:
		spawn.despawn_player(id)

func _spawn_player(peer_id: int) -> void:
	var spawn := _get_spawn_points_node()
	if spawn:
		spawn.spawn_player(peer_id)
		if multiplayer.is_server():
			print("[Dedicated Server] Spawn request for peer: %s" % peer_id)

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
