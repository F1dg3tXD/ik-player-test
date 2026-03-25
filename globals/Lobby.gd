extends Node

signal lobby_created(room_code: String)
signal lobby_joined(room_code: String)

const DEDICATED_SERVER_FLAG := "-server"
const SERVER_UI_SCENE := preload("res://server_ui.tscn")

var active_room_code := ""
var _pending_profiles: Dictionary = {}

@onready var _scene_tree := get_tree()

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	NetworkManager.remote_profile_received.connect(_on_remote_profile_received)

	if _is_dedicated_server_mode():
		call_deferred("_start_dedicated_server")

func host_webrtc_lobby(room_code: String, signaling_url: String, spawn_local_player: bool = true) -> Error:
	var result := await NetworkManager.start_webrtc_host(room_code, signaling_url)
	if result != OK:
		return result

	active_room_code = NetworkManager.get_active_room_code()

	if spawn_local_player:
		await _scene_tree.process_frame
		_spawn_player(NetworkManager.get_local_peer_id())

	_hide_menu()
	emit_signal("lobby_created", active_room_code)
	return OK

func join_webrtc_lobby(room_code: String, signaling_url: String) -> Error:
	var result := await NetworkManager.start_webrtc_client(room_code, signaling_url)
	if result != OK:
		return result

	active_room_code = NetworkManager.get_active_room_code()

	emit_signal("lobby_joined", active_room_code)
	return OK

func _start_dedicated_server() -> void:
	_mount_server_ui()
	var room_code := _get_dedicated_arg_value("-room=", "")
	var signaling_url := _get_dedicated_arg_value("-signaling-url=", NetworkManager.DEFAULT_SIGNALING_URL)
	var result := await host_webrtc_lobby(room_code, signaling_url, false)
	if result != OK:
		push_error("[Dedicated Server] Failed to start host (%s) using %s" % [result, signaling_url])
		return

	print("[Dedicated Server] Started room '%s' with signaling URL %s" % [active_room_code, signaling_url])
	print("[Dedicated Server] Server peer ID: %s" % NetworkManager.get_local_peer_id())
	print("[Dedicated Server] Waiting for players to connect...")


func _mount_server_ui() -> void:
	if SERVER_UI_SCENE == null:
		return
	var scene := _scene_tree.current_scene
	if scene == null:
		return
	if scene.get_node_or_null("ServerUI"):
		return
	var server_ui := SERVER_UI_SCENE.instantiate()
	server_ui.name = "ServerUI"
	scene.add_child(server_ui)

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
	_pending_profiles.erase(id)

func _spawn_player(peer_id: int) -> void:
	var spawn := _get_spawn_points_node()
	if spawn:
		spawn.spawn_player(peer_id)
	_apply_profile_if_ready(peer_id)
	if multiplayer.is_server():
		print("[Dedicated Server] Spawn request for peer: %s" % peer_id)

func _on_remote_profile_received(peer_id: int, player_name: String, icon_png_base64: String) -> void:
	_pending_profiles[peer_id] = {
		"player_name": player_name,
		"icon_png_base64": icon_png_base64
	}
	_apply_profile_if_ready(peer_id)

func _apply_profile_if_ready(peer_id: int) -> void:
	if not _pending_profiles.has(peer_id):
		return
	var scene := _scene_tree.current_scene
	if scene == null:
		return
	var players := scene.get_node_or_null("Players")
	if players == null:
		return
	var player_node := players.get_node_or_null(str(peer_id))
	if player_node == null:
		return
	if not player_node.has_method("apply_remote_profile"):
		return
	var profile: Dictionary = _pending_profiles[peer_id]
	player_node.apply_remote_profile(
		str(profile.get("player_name", "Player")),
		str(profile.get("icon_png_base64", ""))
	)

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
