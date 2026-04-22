extends Node

signal lobby_created(room_code: String)
signal lobby_joined(room_code: String)

const DEDICATED_SERVER_FLAG := "-server"
const SERVER_UI_SCENE := preload("res://server_ui.tscn")

var active_room_code := ""
var _session_started := false
var _last_seed := 0
var _network_manager: Node = null
var _scene_tree: SceneTree = null

func _ready() -> void:
	_scene_tree = get_tree()
	_network_manager = _scene_tree.root.get_node_or_null("NetworkManager")
	if _is_dedicated_server_mode():
		call_deferred("_start_dedicated_server")

func host_lobby(room_code: String, signaling_url: String = "") -> Error:
	if _network_manager:
		_network_manager.session_created.connect(_on_session_created)
		_network_manager.error_raised.connect(_on_lobby_error)
	
	var result: Error = ERR_CANT_CREATE
	if _network_manager:
		result = _network_manager.create_session(true)
	if result != OK:
		return result
	
	_await_session_start()
	return OK

func join_lobby(room_code: String, signaling_url: String = "") -> Error:
	if _network_manager:
		_network_manager.session_joined.connect(_on_session_joined)
		_network_manager.error_raised.connect(_on_lobby_error)
	
	var result: Error = ERR_CANT_CREATE
	if _network_manager:
		result = _network_manager.join_session(room_code)
	if result != OK:
		return result
	
	_await_session_start()
	return OK

func _await_session_start() -> void:
	var timeout := 0
	while not _session_started and timeout < 300:
		await _scene_tree.process_frame
		timeout += 1
		if _session_started:
			break
	
	if not _session_started:
		push_error("Session start timed out")

func _on_session_created(room_code: String) -> void:
	_session_started = true
	active_room_code = room_code
	_hide_menu()
	emit_signal("lobby_created", active_room_code)

func _on_session_joined(room_code: String) -> void:
	_session_started = true
	active_room_code = room_code
	_hide_menu()
	emit_signal("lobby_joined", active_room_code)

func _on_lobby_error(message: String) -> void:
	push_error("Lobby error: ", message)
	_session_started = false

func _start_dedicated_server() -> void:
	_mount_server_ui()
	var room_code := _get_dedicated_arg_value("-room=", "")
	if _network_manager:
		_network_manager.session_created.connect(_on_session_created)
	
	var result: Error = ERR_CANT_CREATE
	if _network_manager:
		result = _network_manager.create_session(true)
	if result != OK:
		push_error("[Dedicated Server] Failed to start host")
		return
	
	_await_session_start()
	if _network_manager and _network_manager.has("active_room_code"):
		print("[Dedicated Server] Started room with code: ", _network_manager.get("active_room_code"))
	print("[Dedicated Server] Waiting for players...")

func _mount_server_ui() -> void:
	if SERVER_UI_SCENE == null:
		return
	var scene := _scene_tree.current_scene
	if scene == null:
		return
	if scene.get_node_or_null("ServerUI"):
		return
	var server_ui = SERVER_UI_SCENE.instantiate()
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

func _hide_menu() -> void:
	var scene = _scene_tree.current_scene
	if scene == null:
		return
	var menu = scene.get_node_or_null("Menu")
	if menu:
		menu.visible = false

func get_players_parent() -> Node:
	var scene = _scene_tree.current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("World/Players")

func get_spawn_points() -> Node:
	var scene = _scene_tree.current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("World/LobbyMap/spawnPoints")

var is_host: bool:
	get:
		if _network_manager and _network_manager.has_method("is_host"):
			return _network_manager.is_host()
		return false

var room_code: String:
	get:
		if _network_manager and _network_manager.has("active_room_code"):
			return _network_manager.get("active_room_code")
		return ""
